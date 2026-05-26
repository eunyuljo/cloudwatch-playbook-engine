import json
import logging
import os

from playbooks import PlaybookRegistry
from notifier import Notifier
from utils import extract_alarm_key

logger = logging.getLogger("runbook_engine")
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))

RUNBOOK_SUBJECT_PREFIX = "[Runbook]"


def lambda_handler(event, context):
    notifier = Notifier(topic_arn=os.environ["NOTIFICATION_TOPIC_ARN"])

    for record in event["Records"]:
        try:
            sns_message = record["Sns"]
            subject = sns_message.get("Subject", "")

            if subject.startswith(RUNBOOK_SUBJECT_PREFIX):
                logger.info("Skipping self-generated message: %s", subject)
                continue

            message = json.loads(sns_message["Message"])
        except (json.JSONDecodeError, KeyError, TypeError) as e:
            logger.error("Failed to parse SNS message: %s", str(e))
            continue

        if not isinstance(message, dict) or "AlarmName" not in message:
            logger.info("Skipping non-alarm message")
            continue

        if message.get("NewStateValue") != "ALARM":
            logger.info("Skipping non-ALARM state: %s", message.get("NewStateValue"))
            continue

        alarm_name = message["AlarmName"]
        alarm_key = extract_alarm_key(alarm_name)
        logger.info("Processing alarm: %s (key: %s)", alarm_name, alarm_key)

        playbook = PlaybookRegistry.get(alarm_key)
        if playbook is None:
            logger.warning("No playbook found for alarm key: %s", alarm_key)
            notifier.send_no_playbook(alarm_name, message)
            continue

        try:
            result = playbook.run(message)
            notifier.send_diagnosis(result)
            logger.info("Playbook completed: verdict=%s", result.verdict)
        except Exception as e:
            logger.exception("Playbook execution failed for %s", alarm_key)
            notifier.send_error(alarm_name, str(e))
