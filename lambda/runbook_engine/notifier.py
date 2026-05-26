import json
import boto3

from playbooks.base import DiagnosisResult


class Notifier:
    def __init__(self, topic_arn: str):
        self._sns = boto3.client("sns")
        self._topic_arn = topic_arn

    def send_diagnosis(self, result: DiagnosisResult):
        message = self._format_diagnosis(result)
        self._sns.publish(
            TopicArn=self._topic_arn,
            Subject=f"[Runbook] {result.severity} - {result.alarm_name}",
            Message=message,
        )

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
