# Next Steps

## Immediate Next Playbooks

Recommended order:

1. `ecs-task-count-low.md`
2. `ecs-deployment-failure.md`
3. `aurora-connections-high.md`
4. `aurora-storage-low.md`
5. `lambda-errors-throttles.md`
6. `guardduty-high-finding.md`
7. `cloudtrail-stop-logging.md`

## Next Process Steps

### 1. Validate AWS metric names

Use AWS documentation to confirm metric names, dimensions, and service-specific
limits before turning this guide into production policy.

### 2. Add environment-specific values

Replace placeholders with:

- Account IDs
- Region list
- ALB names
- Target group ARNs
- ECS cluster names
- ECS service names
- Log group names
- Customer escalation contacts

### 3. Create alarm definitions

Turn the monitoring matrix into:

- CloudWatch alarms
- Terraform/CDK definitions
- PagerDuty or Slack routing rules
- Runbook links in alarm descriptions

### 4. Add incident reporting

Create templates for:

- Initial notification
- Periodic status update
- Recovery notification
- Post-incident review
- Monthly operations report

### 5. Run tabletop exercises

Practice scenarios:

- ALB target 5xx after deployment
- ECS task count drops below desired
- Aurora connection saturation
- GuardDuty high severity finding
- CloudTrail logging disabled

## Production Readiness Checklist

- Each P1/P2 alarm has a playbook.
- Each playbook has clear owner and escalation rules.
- MSP allowed actions are explicitly approved.
- Customer responsibilities are documented.
- Alarm thresholds are tuned with baseline data.
- Playbooks have been tested in tabletop exercises.
- AWS documentation assumptions are verified.
