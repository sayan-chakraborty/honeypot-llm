"""Azure Table Storage helper — stores attack transcripts and logs."""

import logging
import os

from azure.data.tables import TableServiceClient

_table_client = None


def _get_table_client(table_name: str = "AttackLogs"):
    """Lazy-initialize the Table Storage client."""
    global _table_client
    if _table_client is None:
        conn_str = os.environ["STORAGE_CONNECTION_STRING"]
        service = TableServiceClient.from_connection_string(conn_str)
        _table_client = service.get_table_client(table_name)
    return _table_client


def store_attack_log(record: dict) -> None:
    """Upsert an attack log entry into Table Storage."""
    client = _get_table_client("AttackLogs")
    try:
        client.upsert_entity(record)
        logging.info(f"Stored attack log: PK={record['PartitionKey']}, RK={record['RowKey']}")
    except Exception as e:
        logging.error(f"Failed to store attack log: {e}", exc_info=True)
        raise


def get_attack_logs(partition_key: str | None = None) -> list[dict]:
    """Retrieve attack logs, optionally filtered by date (partition key)."""
    client = _get_table_client("AttackLogs")
    if partition_key:
        query = f"PartitionKey eq '{partition_key}'"
        return list(client.query_entities(query))
    return list(client.list_entities())
