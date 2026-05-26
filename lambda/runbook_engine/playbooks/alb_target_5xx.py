import os
import time
import logging

import boto3

from .base import BasePlaybook, DiagnosisResult

logger = logging.getLogger("runbook_engine")


class AlbTarget5xxPlaybook(BasePlaybook):
    @property
    def alarm_keys(self) -> list:
        return ["alb_target_5xx", "alb_unhealthy_host"]

    def run(self, alarm_message: dict) -> DiagnosisResult:
        target_group_arn = os.environ.get("TARGET_GROUP_ARN", "")
        cluster_name = os.environ.get("ECS_CLUSTER_NAME", "")
        service_name = os.environ.get("ECS_SERVICE_NAME", "")
        log_group_name = os.environ.get("APP_LOG_GROUP_NAME", "")

        if not target_group_arn:
            return DiagnosisResult(
                alarm_name=alarm_message["AlarmName"],
                severity="P2",
                verdict="CONFIG_ERROR",
                summary="TARGET_GROUP_ARN environment variable is not configured.",
                details={"missing_config": "TARGET_GROUP_ARN"},
                recommended_action="Configure TARGET_GROUP_ARN in Lambda environment variables.",
            )

        target_health = self._check_target_health(target_group_arn)
        service_status = self._check_ecs_service(cluster_name, service_name)
        recent_errors = self._check_logs(log_group_name)

        return self._evaluate(
            alarm_message["AlarmName"],
            target_health,
            service_status,
            recent_errors,
        )

    def _check_target_health(self, target_group_arn: str) -> dict:
        elbv2 = boto3.client("elbv2")
        response = elbv2.describe_target_health(TargetGroupArn=target_group_arn)

        healthy = 0
        unhealthy = 0
        reasons = []

        for desc in response["TargetHealthDescriptions"]:
            state = desc["TargetHealth"]["State"]
            if state == "healthy":
                healthy += 1
            else:
                unhealthy += 1
                reason = desc["TargetHealth"].get("Reason", "unknown")
                reasons.append(reason)

        return {
            "healthy": healthy,
            "unhealthy": unhealthy,
            "total": healthy + unhealthy,
            "reasons": reasons,
        }

    def _check_ecs_service(self, cluster_name: str, service_name: str) -> dict:
        if not cluster_name or not service_name:
            return {"available": False}

        ecs = boto3.client("ecs")
        response = ecs.describe_services(
            cluster=cluster_name, services=[service_name]
        )

        if not response["services"]:
            return {"available": False}

        service = response["services"][0]
        deployments = service.get("deployments", [])
        has_active_deployment = len(deployments) > 1

        return {
            "available": True,
            "desired_count": service["desiredCount"],
            "running_count": service["runningCount"],
            "pending_count": service["pendingCount"],
            "has_active_deployment": has_active_deployment,
            "deployment_count": len(deployments),
        }

    def _check_logs(self, log_group_name: str) -> dict:
        if not log_group_name:
            return {"available": False, "errors": []}

        logs = boto3.client("logs")
        end_time = int(time.time() * 1000)
        start_time = end_time - (5 * 60 * 1000)

        try:
            response = logs.filter_log_events(
                logGroupName=log_group_name,
                startTime=start_time,
                endTime=end_time,
                filterPattern="ERROR",
                limit=20,
            )
            events = [e["message"][:200] for e in response.get("events", [])]
            return {"available": True, "errors": events, "count": len(events)}
        except Exception as e:
            logger.warning("Log query failed: %s", str(e))
            return {"available": False, "errors": [], "error": str(e)}

    def _evaluate(
        self,
        alarm_name: str,
        target_health: dict,
        service_status: dict,
        recent_errors: dict,
    ) -> DiagnosisResult:
        unhealthy = target_health["unhealthy"]
        total = target_health["total"]

        if total > 0 and unhealthy == total:
            return DiagnosisResult(
                alarm_name=alarm_name,
                severity="P1",
                verdict="ALL_TARGETS_UNHEALTHY",
                summary=f"All {total} targets are unhealthy.",
                details={
                    "unhealthy_count": unhealthy,
                    "total_count": total,
                    "reasons": target_health["reasons"],
                    "ecs_running": service_status.get("running_count", "N/A"),
                    "ecs_desired": service_status.get("desired_count", "N/A"),
                },
                recommended_action="Escalate to MSP L2 and customer app team immediately. Check ECS service health and consider rollback.",
            )

        if unhealthy > 0:
            has_deployment = service_status.get("has_active_deployment", False)
            action = (
                "Recent deployment detected. Gather evidence and ask customer for rollback decision."
                if has_deployment
                else "Monitor ECS task replacement. Escalate if failures repeat or spread."
            )
            return DiagnosisResult(
                alarm_name=alarm_name,
                severity="P2",
                verdict="PARTIAL_TARGETS_UNHEALTHY",
                summary=f"{unhealthy}/{total} targets unhealthy.",
                details={
                    "unhealthy_count": unhealthy,
                    "total_count": total,
                    "reasons": target_health["reasons"],
                    "ecs_running": service_status.get("running_count", "N/A"),
                    "ecs_desired": service_status.get("desired_count", "N/A"),
                    "active_deployment": has_deployment,
                },
                recommended_action=action,
            )

        error_count = recent_errors.get("count", 0)
        return DiagnosisResult(
            alarm_name=alarm_name,
            severity="P2",
            verdict="TARGETS_HEALTHY_APP_ERROR",
            summary=f"All {total} targets healthy but 5xx continues. {error_count} recent errors in logs.",
            details={
                "healthy_count": target_health["healthy"],
                "total_count": total,
                "recent_error_count": error_count,
                "sample_errors": recent_errors.get("errors", [])[:5],
                "ecs_running": service_status.get("running_count", "N/A"),
            },
            recommended_action="Suspect application-side failure. Escalate to customer app team with log evidence.",
        )
