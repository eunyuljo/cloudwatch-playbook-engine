import json
import logging
import os
from urllib.request import Request, urlopen
from urllib.error import URLError

import boto3

from playbooks.base import DiagnosisResult

logger = logging.getLogger("runbook_engine")

SEVERITY_EMOJI = {"P1": ":red_circle:", "P2": ":large_orange_circle:", "P3": ":large_yellow_circle:", "P4": ":white_circle:"}
SEVERITY_COLOR = {"P1": "#FF0000", "P2": "#FF8C00", "P3": "#FFD700", "P4": "#808080"}


class Notifier:
    def __init__(self, topic_arn: str):
        self._sns = boto3.client("sns")
        self._topic_arn = topic_arn
        self._slack_webhook_url = os.environ.get("SLACK_WEBHOOK_URL", "")

    def send_diagnosis(self, result: DiagnosisResult):
        message = self._format_diagnosis(result)
        self._sns.publish(
            TopicArn=self._topic_arn,
            Subject=f"[Runbook] {result.severity} - {result.alarm_name}",
            Message=message,
        )
        if self._slack_webhook_url:
            self._send_slack_diagnosis(result)

    def send_no_playbook(self, alarm_name: str, alarm_message: dict):
        message = (
            f"[Runbook] No playbook found\n\n"
            f"Alarm: {alarm_name}\n"
            f"State: {alarm_message.get('NewStateValue')}\n"
            f"Reason: {alarm_message.get('NewStateReason', 'N/A')}\n\n"
            f"Manual triage required."
        )
        self._sns.publish(
            TopicArn=self._topic_arn,
            Subject=f"[Runbook] No playbook - {alarm_name}",
            Message=message,
        )
        if self._slack_webhook_url:
            self._send_slack_text(f":warning: *No playbook found*\nAlarm: `{alarm_name}`\nManual triage required.")

    def send_error(self, alarm_name: str, error: str):
        message = (
            f"[Runbook] Playbook execution failed\n\n"
            f"Alarm: {alarm_name}\n"
            f"Error: {error}\n\n"
            f"Manual triage required."
        )
        self._sns.publish(
            TopicArn=self._topic_arn,
            Subject=f"[Runbook] ERROR - {alarm_name}",
            Message=message,
        )
        if self._slack_webhook_url:
            self._send_slack_text(f":x: *Playbook execution failed*\nAlarm: `{alarm_name}`\nError: {error}")

    def _format_diagnosis(self, result: DiagnosisResult) -> str:
        lines = [
            f"[{result.severity}] {result.alarm_name}",
            "",
            f"Verdict: {result.verdict}",
            f"Summary: {result.summary}",
            "",
            "Details:",
        ]
        for key, value in result.details.items():
            lines.append(f"  {key}: {value}")
        lines.extend(["", f"Recommended Action: {result.recommended_action}"])
        return "\n".join(lines)

    def _send_slack_diagnosis(self, result: DiagnosisResult):
        emoji = SEVERITY_EMOJI.get(result.severity, ":question:")
        color = SEVERITY_COLOR.get(result.severity, "#808080")

        details_text = "\n".join(f"• *{k}*: {v}" for k, v in result.details.items())

        blocks = [
            {
                "type": "header",
                "text": {"type": "plain_text", "text": f"{result.severity} Alert - Runbook Diagnosis"}
            },
            {
                "type": "section",
                "text": {"type": "mrkdwn", "text": f"{emoji} *{result.alarm_name}*"}
            },
            {
                "type": "section",
                "fields": [
                    {"type": "mrkdwn", "text": f"*Verdict:*\n`{result.verdict}`"},
                    {"type": "mrkdwn", "text": f"*Severity:*\n{result.severity}"},
                ]
            },
            {
                "type": "section",
                "text": {"type": "mrkdwn", "text": f"*Summary:*\n{result.summary}"}
            },
            {
                "type": "section",
                "text": {"type": "mrkdwn", "text": f"*Details:*\n{details_text}"}
            },
            {"type": "divider"},
            {
                "type": "section",
                "text": {"type": "mrkdwn", "text": f":point_right: *Recommended Action:*\n{result.recommended_action}"}
            },
        ]

        payload = {
            "blocks": blocks,
            "attachments": [{"color": color, "blocks": []}],
        }
        self._post_slack(payload)

    def _send_slack_text(self, text: str):
        self._post_slack({"text": text})

    def _post_slack(self, payload: dict):
        try:
            data = json.dumps(payload).encode("utf-8")
            req = Request(self._slack_webhook_url, data=data, headers={"Content-Type": "application/json"})
            urlopen(req, timeout=5)
        except URLError as e:
            logger.error("Slack notification failed: %s", str(e))
