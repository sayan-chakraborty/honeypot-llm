import azure.functions as func
import json
import logging
from datetime import datetime, timezone

from shared.table_client import store_attack_log
from shared.attack_classifier import classify_attack
from shared.rule_generator import generate_rule
from shared.app_config_client import push_rule

app = func.FunctionApp()


@app.route(route="logAttack", methods=["POST"], auth_level=func.AuthLevel.FUNCTION)
def log_attack(req: func.HttpRequest) -> func.HttpResponse:
    """
    Receives attack data from APIM send-one-way-request policy.
    Classifies the attack, stores transcript, generates hardening rule.
    """
    try:
        payload = req.get_json()
        logging.info(f"Attack received from IP: {payload.get('attackerIP')}")

        # Step 1: Classify the attack type
        classification = classify_attack(payload["originalPrompt"])
        logging.info(
            f"Classified as: {classification['type']} "
            f"(confidence: {classification['confidence']})"
        )

        # Step 2: Store the full transcript in Table Storage
        attack_record = {
            "PartitionKey": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
            "RowKey": payload.get("requestId", datetime.now(timezone.utc).isoformat()),
            "Timestamp": payload.get("timestamp", datetime.now(timezone.utc).isoformat()),
            "AttackerIP": payload.get("attackerIP", "unknown"),
            "OriginalPrompt": payload.get("originalPrompt", ""),
            "ShadowResponse": payload.get("shadowResponse", "")[:32000],  # Truncate if huge
            "AttackType": classification["type"],
            "Confidence": classification["confidence"],
            "Techniques": json.dumps(classification["techniques"]),
        }
        store_attack_log(attack_record)
        logging.info(f"Attack log stored: {attack_record['RowKey']}")

        # Step 3: Generate and push a hardening rule
        rule = generate_rule(classification, payload.get("originalPrompt", ""))
        if rule:
            push_rule(rule)
            logging.info(f"Hardening rule pushed: {rule['ruleId']}")

        return func.HttpResponse(
            json.dumps({"status": "accepted", "attackType": classification["type"]}),
            status_code=202,
            mimetype="application/json",
        )

    except Exception as e:
        logging.error(f"Error processing attack log: {e}", exc_info=True)
        return func.HttpResponse(
            json.dumps({"status": "error", "message": str(e)}),
            status_code=500,
            mimetype="application/json",
        )


@app.route(route="health", methods=["GET"], auth_level=func.AuthLevel.ANONYMOUS)
def health_check(req: func.HttpRequest) -> func.HttpResponse:
    """Simple health check endpoint."""
    return func.HttpResponse(
        json.dumps({"status": "healthy", "timestamp": datetime.now(timezone.utc).isoformat()}),
        status_code=200,
        mimetype="application/json",
    )
