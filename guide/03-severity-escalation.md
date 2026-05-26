# 3. Severity and Escalation

## Purpose

Severity and escalation rules define how urgent an event is, who responds, and
when the incident must move to MSP L2 or the customer team.

## Severity Definitions

| Severity | Meaning | Examples | First Response Target | Escalation |
|---|---|---|---:|---|
| P1 | Major outage, data-loss risk, or security compromise risk | Large CloudFront/ALB 5xx, all ECS tasks down, Aurora writer unavailable, CloudTrail stopped, high-risk GuardDuty finding | 5 min | Immediate MSP L2 and customer contact |
| P2 | User impact exists, but not a full outage | ALB target 5xx increase, partial ECS task failure, DB connection saturation, sustained Lambda errors | 15 min | Escalate if unresolved in 30 min or customer impact is confirmed |
| P3 | Degradation or early warning | High CPU/memory, latency increase, WAF block spike, storage growth trend | 4 hours | L2 review during business hours |
| P4 | Preventive or informational issue | Capacity trend, recurring warning, cost growth signal | 1 business day | Track in backlog or monthly report |
| Info | Reference event | Deployment completed, one-time metric spike | As needed | No escalation by default |

## Severity Decision Questions

1. Is there confirmed user impact?
2. Is the impact full-service or partial?
3. Is there any data-loss or security-compromise risk?
4. Is the signal still active or already recovered?
5. Can the MSP act under approved authority?
6. Does the incident require customer business judgment?

## Escalation Policy

### P1

- Confirm alarm within 5 minutes.
- Notify MSP L2 immediately.
- Notify the customer incident channel immediately.
- Send the first status update within 15 minutes.
- Continue updates every 30 minutes until recovery.
- Require post-incident review.

### P2

- Confirm alarm within 15 minutes.
- Perform first-level triage.
- Escalate to MSP L2 and customer if unresolved within 30 minutes.
- Escalate immediately when customer impact is confirmed.
- Send updates every 60 minutes while active.
- Recommend post-incident review for recurring issues.

### P3

- Review within 4 hours.
- Analyze during business hours.
- Prefer trend review and preventive action over emergency change.
- Convert recurring issues into improvement tasks.

### P4

- Review within 1 business day.
- Track through backlog, weekly review, or monthly report.
- Do not page unless the signal worsens.

## MSP and Customer Responsibility Split

| Activity | MSP | Customer |
|---|---|---|
| CloudWatch alarm review | Responsible | Informed |
| AWS resource health check | Responsible | Informed |
| Pre-approved scale action | Responsible | Approves policy |
| Application code fix | Excluded | Responsible |
| Direct DB data change | Excluded | Responsible |
| Public incident notice | Supports | Responsible |
| Security finding triage | Responsible for first review | Responsible for final risk decision |
| Cost and capacity report | Responsible | Responsible for budget decisions |

## Escalation Message Template

```text
[Severity] [Service] [Issue Summary]

Time:
Region:
Affected service:
Detected by:
Current impact:
Initial finding:
Action taken:
Need from customer:
Next update:
```

## Example

```text
[P2] ALB Target 5xx increase detected

Time: 2026-05-26 10:15 UTC
Region: ap-northeast-2
Affected service: web-api ECS service behind ALB
Detected by: CloudWatch alarm alb-target-5xx-high
Current impact: Some API requests may be failing
Initial finding: ELB 5xx is low, Target 5xx increased
Action taken: Checking target health and ECS service events
Need from customer: Confirm whether an application deployment occurred recently
Next update: Within 30 minutes
```
