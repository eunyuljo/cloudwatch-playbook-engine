# AWS MSP Operations Guide

This guide captures the sample AWS MSP operations process built in this chat.
It is written as a practical walkthrough for designing monitoring standards,
severity rules, escalation policy, and incident playbooks with AI-assisted
workflows.

## Scope

- Target: sample AWS web application
- Region: `ap-northeast-2`
- Operation model: 24x7 monitoring
- MSP scope: monitoring, first response, pre-approved infrastructure actions,
  escalation, and reporting
- Out of scope: application code fixes, direct production data changes, and
  unapproved production rollback

## Sample Architecture

- Edge: Route 53, CloudFront, AWS WAF
- Load balancing: Application Load Balancer
- Compute: ECS Fargate, Lambda
- Database: Aurora MySQL
- Storage: S3
- Observability: CloudWatch, CloudWatch Logs, CloudTrail
- Security: IAM, GuardDuty

## Guide Structure

1. [Operating Scope](./01-operating-scope.md)
2. [Monitoring Matrix](./02-monitoring-matrix.md)
3. [Severity and Escalation](./03-severity-escalation.md)
4. [ALB Target 5xx Playbook](./04-playbook-alb-target-5xx.md)
5. [Playbook Template](./templates/playbook-template.md)
6. [AI Workflow](./ai-workflow.md)
7. [Next Steps](./next-steps.md)

## Recommended Process

```text
Define operating scope
-> Select service signals and monitoring matrix
-> Define severity and escalation rules
-> Write service-specific playbooks
-> Review with LLM-as-judge
-> Validate against AWS documentation and real incidents
-> Improve through post-incident reviews
```
