"""Azure App Configuration helper — pushes hardening rules."""

import json
import logging
import os

from azure.appconfiguration import AzureAppConfigurationClient

_config_client = None


def _get_config_client():
    """Lazy-initialize the App Configuration client."""
    global _config_client
    if _config_client is None:
        conn_str = os.environ.get("APP_CONFIG_CONNECTION_STRING", "")
        if not conn_str:
            logging.warning("APP_CONFIG_CONNECTION_STRING not set — rules will not be pushed")
            return None
        _config_client = AzureAppConfigurationClient.from_connection_string(conn_str)
    return _config_client


def push_rule(rule: dict) -> None:
    """Push a hardening rule to App Configuration as a key-value pair."""
    client = _get_config_client()
    if client is None:
        logging.warning(f"Skipping rule push (no App Config client): {rule['ruleId']}")
        return

    try:
        from azure.appconfiguration import ConfigurationSetting

        setting = ConfigurationSetting(
            key=f"honeypot/rules/{rule['ruleId']}",
            value=json.dumps(rule),
            label="hardening-rule",
            content_type="application/json",
        )
        client.set_configuration_setting(setting)
        logging.info(f"Pushed rule to App Configuration: {rule['ruleId']}")
    except Exception as e:
        logging.error(f"Failed to push rule to App Configuration: {e}", exc_info=True)
        raise


def get_all_rules() -> list[dict]:
    """Retrieve all hardening rules from App Configuration."""
    client = _get_config_client()
    if client is None:
        return []

    rules = []
    settings = client.list_configuration_settings(
        key_filter="honeypot/rules/*",
        label_filter="hardening-rule",
    )
    for setting in settings:
        try:
            rules.append(json.loads(setting.value))
        except json.JSONDecodeError:
            logging.warning(f"Invalid JSON in rule: {setting.key}")
    return rules
