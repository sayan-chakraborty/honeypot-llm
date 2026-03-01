import azure.functions as func
import json
import logging
from datetime import datetime, timezone

from shared.table_client import store_attack_log, get_attack_logs
from shared.attack_classifier import classify_attack
from shared.rule_generator import generate_rule
from shared.app_config_client import push_rule, get_all_rules

app = func.FunctionApp()


# ── CORS helper ──────────────────────────────────────────────────────────
def _cors_headers() -> dict:
    return {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, api-key",
    }


def _cors_response(body: str, status_code: int = 200) -> func.HttpResponse:
    return func.HttpResponse(
        body, status_code=status_code, mimetype="application/json", headers=_cors_headers()
    )


# ── Attack Logs API (read) ───────────────────────────────────────────────
@app.route(route="attackLogs", methods=["GET", "OPTIONS"], auth_level=func.AuthLevel.ANONYMOUS)
def attack_logs(req: func.HttpRequest) -> func.HttpResponse:
    """Return attack logs from Table Storage. Optional ?date=YYYY-MM-DD filter."""
    if req.method == "OPTIONS":
        return _cors_response("", 204)
    try:
        date_filter = req.params.get("date")
        logs = get_attack_logs(partition_key=date_filter)
        # Convert non-serialisable fields and sort newest-first
        sanitised = []
        for log in logs:
            entry = {}
            for k, v in log.items():
                if k.startswith("odata") or k.startswith("_"):
                    continue
                entry[k] = str(v) if not isinstance(v, (str, int, float, bool, type(None))) else v
            sanitised.append(entry)
        sanitised.sort(key=lambda x: x.get("Timestamp", ""), reverse=True)
        return _cors_response(json.dumps(sanitised))
    except Exception as e:
        logging.error(f"Error fetching attack logs: {e}", exc_info=True)
        return _cors_response(json.dumps({"error": str(e)}), 500)


# ── Hardening Rules API (read) ───────────────────────────────────────────
@app.route(route="rules", methods=["GET", "OPTIONS"], auth_level=func.AuthLevel.ANONYMOUS)
def rules(req: func.HttpRequest) -> func.HttpResponse:
    """Return all hardening rules from App Configuration."""
    if req.method == "OPTIONS":
        return _cors_response("", 204)
    try:
        all_rules = get_all_rules()
        return _cors_response(json.dumps(all_rules, default=str))
    except Exception as e:
        logging.error(f"Error fetching rules: {e}", exc_info=True)
        return _cors_response(json.dumps({"error": str(e)}), 500)


# ── Log Attack API (write — called by APIM fire-and-forget) ──────────────
@app.route(route="logAttack", methods=["POST", "OPTIONS"], auth_level=func.AuthLevel.FUNCTION)
def log_attack(req: func.HttpRequest) -> func.HttpResponse:
    """
    Receives attack data from APIM send-one-way-request policy.
    Classifies the attack, stores transcript, generates hardening rule.
    """
    if req.method == "OPTIONS":
        return _cors_response("", 204)
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

        return _cors_response(
            json.dumps({"status": "accepted", "attackType": classification["type"]}),
            202,
        )

    except Exception as e:
        logging.error(f"Error processing attack log: {e}", exc_info=True)
        return _cors_response(
            json.dumps({"status": "error", "message": str(e)}),
            500,
        )


@app.route(route="health", methods=["GET", "OPTIONS"], auth_level=func.AuthLevel.ANONYMOUS)
def health_check(req: func.HttpRequest) -> func.HttpResponse:
    """Simple health check endpoint."""
    if req.method == "OPTIONS":
        return _cors_response("", 204)
    return _cors_response(
        json.dumps({"status": "healthy", "timestamp": datetime.now(timezone.utc).isoformat()}),
    )
