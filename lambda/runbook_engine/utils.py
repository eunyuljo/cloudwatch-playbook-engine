import os
import logging

logger = logging.getLogger("runbook_engine")


def extract_alarm_key(alarm_name: str) -> str:
    project = os.environ.get("PROJECT", "")
    environment = os.environ.get("ENVIRONMENT", "")
    prefix = f"{project}-{environment}-"

    if alarm_name.startswith(prefix):
        return alarm_name[len(prefix):]

    parts = alarm_name.rsplit("-", 1)
    return parts[-1] if len(parts) >= 2 else alarm_name
