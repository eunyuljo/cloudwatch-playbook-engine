# 1. Operating Scope

## Purpose

Define what the MSP monitors, what it can change, and when responsibility moves
to the customer or application team. This prevents unclear ownership during an
incident.

## Sample Operating Model

| Item | Value |
|---|---|
| Environment | Sample web application |
| Primary region | `ap-northeast-2` |
| DR region | None for this exercise |
| Operating hours | 24x7 monitoring |
| P1/P2 response | Immediate response |
| P3/P4 response | Business-hours review or scheduled follow-up |

## AWS Services In Scope

| Area | Services |
|---|---|
| Edge | Route 53, CloudFront, AWS WAF |
| Load balancing | ALB |
| Compute | ECS Fargate, Lambda |
| Database | Aurora MySQL |
| Storage | S3 |
| Observability | CloudWatch, CloudWatch Logs, CloudTrail |
| Security | IAM, GuardDuty |

## MSP Responsibilities

- Monitor CloudWatch alarms and security findings.
- Perform first-level triage for infrastructure and platform signals.
- Check AWS resource health, logs, and recent infrastructure events.
- Execute only pre-approved infrastructure actions.
- Escalate to MSP L2 or the customer team with clear evidence.
- Produce incident records and recurring operations reports.

## Customer Responsibilities

- Application code fixes.
- Business impact assessment.
- Production rollback approval unless pre-approved.
- Database data correction or manual data changes.
- External customer communication.
- Budget, architecture, and security policy decisions.

## Key Operating Questions

When an alarm fires, the operator should answer:

1. Is there actual user impact?
2. Is the impact global or partial?
3. Is there any security or data-loss risk?
4. Is this an AWS infrastructure symptom or an application symptom?
5. Can the MSP act under pre-approved authority?
6. Which playbook applies?
7. Who needs the next update, and by when?
