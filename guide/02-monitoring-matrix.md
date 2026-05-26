# 2. Monitoring Matrix

## Purpose

The monitoring matrix maps AWS service signals to operational severity,
first checks, and playbooks. It keeps alert handling consistent across MSP L1
and L2 teams.

## Monitoring Matrix v1

| Service | Signal | Severity | Threshold | First Check | Playbook |
|---|---|---:|---|---|---|
| CloudFront | `5xxErrorRate` | P1/P2 | 5 min over 5% | Origin status, ALB 5xx | `cloudfront-5xx.md` |
| CloudFront | `OriginLatency` | P3 | 5 min over 2x baseline | ALB latency, ECS/RDS status | `cloudfront-origin-latency.md` |
| WAF | `BlockedRequests` spike | P3 | 3x normal baseline | Rule-level block count | `waf-block-spike.md` |
| ALB | `HTTPCode_ELB_5XX_Count` | P1/P2 | 10+ in 5 min | ALB-level failure or listener issue | `alb-elb-5xx.md` |
| ALB | `HTTPCode_Target_5XX_Count` | P2 | 50+ in 5 min | Target group and app logs | `alb-target-5xx.md` |
| ALB | `UnHealthyHostCount` | P1/P2 | 1+ for 5 min | Target health reason | `alb-unhealthy-host.md` |
| ECS | `RunningTaskCount` low | P1/P2 | Below desired count for 5 min | Service events and stopped tasks | `ecs-task-count-low.md` |
| ECS | `CPUUtilization` high | P3 | 80%+ for 15 min | Scaling, traffic, deployment | `ecs-cpu-high.md` |
| ECS | `MemoryUtilization` high | P2/P3 | 85%+ for 10 min | OOM, task restart | `ecs-memory-high.md` |
| Aurora | `DatabaseConnections` high | P2 | 80%+ of max connections | App connection pool, slow query | `aurora-connections-high.md` |
| Aurora | `FreeableMemory` low | P2 | Low for 15 min | Query load, instance pressure | `aurora-memory-low.md` |
| Aurora | `FreeLocalStorage` low | P2 | Below defined threshold | Temp usage, logs, growth | `aurora-storage-low.md` |
| Lambda | `Errors` high | P2 | 10+ in 5 min | Function logs, recent deploy | `lambda-errors.md` |
| Lambda | `Throttles` high | P2 | Sustained throttles | Concurrency limit | `lambda-throttles.md` |
| S3 | `5xxErrors` | P3 | 5+ in 5 min | AWS Health, client retries | `s3-5xx.md` |
| CloudTrail | `StopLogging` | P1 | Any event | Security incident review | `cloudtrail-stop-logging.md` |
| GuardDuty | High severity finding | P1/P2 | Severity 7+ | Finding type and resource | `guardduty-high-finding.md` |

## MSP Triage Principles

- Prefer actionable alerts over exhaustive metric coverage.
- Every P1/P2 alarm should have an owner and playbook.
- Separate infrastructure symptoms from application symptoms.
- Treat security telemetry separately from availability telemetry.
- Tune thresholds with real baselines after initial operation.
