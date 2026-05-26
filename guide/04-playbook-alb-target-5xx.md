# 4. Playbook: ALB Target 5xx High

## Purpose

Use this playbook when `HTTPCode_Target_5XX_Count` increases for an Application
Load Balancer target group. The goal is to determine whether the issue is in the
load balancer layer, target health, application code, or downstream dependency.

## Key Distinction

```text
HTTPCode_ELB_5XX_Count    = ALB or load-balancer layer issue
HTTPCode_Target_5XX_Count = Target, ECS, EC2, or application-side 5xx
```

## Alarm Definition

| Item | Value |
|---|---|
| Alarm name | `alb-target-5xx-high` |
| Metric | `AWS/ApplicationELB HTTPCode_Target_5XX_Count` |
| Severity | P2, upgrade to P1 if broad user impact exists |
| Threshold | 50+ in 5 minutes |
| Evaluation | 1 datapoint / 5 minutes |
| Primary owner | MSP L1 |
| Escalation | MSP L2, customer app team |

## First Assessment

Answer these questions first:

1. Did only Target 5xx increase?
2. Did ELB 5xx increase as well?
3. Is the issue limited to one target group?
4. Is the issue limited to one Availability Zone?
5. Are targets unhealthy?
6. Was there a recent deployment?
7. Are there downstream symptoms in Aurora, Lambda, or other dependencies?

## Triage Procedure

### 1. Compare Target 5xx and ELB 5xx

If Target 5xx increased but ELB 5xx did not, suspect the application or target.
If ELB 5xx also increased, review ALB listener, target connectivity, TLS, and
load-balancer level symptoms.

### 2. Check Target Health

```bash
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN>
```

Check:

- Healthy and unhealthy target counts.
- Unhealthy reason codes.
- Whether failures are isolated to a target, task, instance, or AZ.

### 3. Check ECS Service Events

```bash
aws ecs describe-services \
  --cluster <CLUSTER_NAME> \
  --services <SERVICE_NAME>
```

Check:

- Desired count vs running count.
- Deployment in progress.
- Task placement failures.
- Health check failures.
- Repeated task restarts.

### 4. Check Application Logs

```bash
aws logs filter-log-events \
  --log-group-name <LOG_GROUP_NAME> \
  --start-time <START_TIME_MS> \
  --filter-pattern "ERROR"
```

Check for:

- HTTP 500 stack traces.
- Database connection errors.
- Timeout errors.
- Dependency failures.
- Errors starting immediately after deployment.

### 5. Check Downstream Dependencies

Review related metrics:

- Aurora `DatabaseConnections`
- Aurora `CPUUtilization`
- Aurora `FreeableMemory`
- Aurora `Deadlocks`
- Lambda `Errors`
- Lambda `Throttles`

### 6. Check Recent Changes

Look for:

- ECS deployment or new task definition.
- ALB listener or rule changes.
- Target group health check changes.
- Security group or network ACL changes.
- RDS security group or parameter changes.

## Decision Tree

### All targets are unhealthy

- Treat as possible P1.
- Check ECS service health and deployment state.
- Check whether rollback is required.
- Escalate to MSP L2 and customer app team immediately.

### Some targets are unhealthy

- Treat as P2 unless user impact is broad.
- Check whether ECS is replacing tasks.
- Consider pre-approved scale-out or task replacement.
- Escalate if failures repeat or spread.

### Targets are healthy but Target 5xx increased

- Suspect application-side failure.
- Check application logs and downstream services.
- Escalate to customer app team with evidence.

### Only one AZ is affected

- Check target placement, subnet routing, NAT, and AZ-specific dependencies.
- Consider traffic mitigation only if pre-approved.
- Escalate to MSP L2 for infrastructure review.

### Recent deployment occurred

- Suspect regression.
- Gather deployment time, task definition, error symptoms, and affected endpoints.
- Ask customer app team for rollback decision unless rollback is pre-approved.

## Mitigation Options

Only perform actions approved in the operating agreement:

- Increase ECS desired count.
- Replace unhealthy tasks.
- Deregister a clearly bad target.
- Confirm target draining.
- Request or execute approved rollback.
- Investigate database connection pressure.

Do not perform without approval:

- Application code changes.
- Direct production data changes.
- Unapproved production rollback.
- Broad security group or network changes.

## Escalation Criteria

Escalate to the customer app team when:

- User impact is confirmed.
- 5xx continues for more than 10 minutes.
- Issue starts after a deployment.
- Targets are healthy but application 500s continue.
- DB connection or timeout errors are found.
- MSP has no approved mitigation path.

Upgrade to P1 when:

- All targets are unhealthy.
- Most core API requests fail.
- CloudFront or ALB error rate increases broadly.
- Login, checkout, payment, or other critical functions are affected.

## Customer Message Template

```text
[P2] ALB Target 5xx increase detected

Time:
Region: ap-northeast-2
Alarm: alb-target-5xx-high
Metric: HTTPCode_Target_5XX_Count
Affected ALB:
Target group:
Current impact:
Initial finding:
- ELB 5xx:
- Target 5xx:
- Unhealthy targets:
- Recent ECS deployment:
- App log symptoms:

Action taken:
Need from customer:
Next update:
```

## Completion Criteria

- Target 5xx returns to normal range.
- No unhealthy targets remain.
- ECS desired count and running count match.
- Application error logs decrease.
- Customer receives recovery update.
- Incident timeline is recorded.
