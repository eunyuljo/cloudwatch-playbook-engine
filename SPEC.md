# 1단계 구현 스펙: CloudWatch 알람 + SNS (Terraform)

## 목표

`guide/02-monitoring-matrix.md`에 정의된 16개 모니터링 시그널을 Terraform CloudWatch 알람으로 구현하고,
심각도별 SNS 토픽으로 라우팅하는 인프라 코드를 작성한다.

## 프로젝트 구조

```
infra/
├── main.tf                  # provider, backend (local), 모듈 호출
├── variables.tf             # 공통 변수 (region, project, environment, tags)
├── outputs.tf               # 주요 출력값
├── terraform.tfvars.example # 환경별 값 예시
├── modules/
│   ├── sns/
│   │   ├── main.tf          # SNS 토픽 (P1P2, P3P4)
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── alarms/
│       ├── main.tf          # 전체 알람 정의 (for_each)
│       ├── variables.tf
│       └── outputs.tf
└── alarms.auto.tfvars       # 알람 정의 map (매트릭스 기반)
```

## 설계 결정

### Provider
- AWS provider, region = var.region (기본값 ap-northeast-2)
- Backend = local (실습용)

### SNS 토픽 구조
- `msp-alerts-p1p2` — P1, P2 알람용 (즉시 대응)
- `msp-alerts-p3p4` — P3, P4 알람용 (업무시간 검토)
- 각 토픽에 email subscription 1개 (변수로 받음)

### 알람 모듈 설계

`for_each`로 알람을 선언적으로 관리한다. 알람 정의는 map(object) 변수로 전달:

```hcl
variable "alarms" {
  type = map(object({
    namespace           = string
    metric_name         = string
    statistic           = string       # "Sum", "Average", "Maximum"
    comparison_operator = string       # "GreaterThanThreshold" 등
    threshold           = number
    period              = number       # seconds
    evaluation_periods  = number
    datapoints_to_alarm = number
    treat_missing_data  = string       # "notBreaching", "breaching", "missing"
    severity            = string       # "P1", "P2", "P3"
    dimensions          = map(string)
    description         = string       # 플레이북 경로 포함
  }))
}
```

### 알람 → SNS 라우팅 규칙
- severity P1 또는 P2 → `msp-alerts-p1p2` 토픽
- severity P3 또는 P4 → `msp-alerts-p3p4` 토픽
- 알람 description에 플레이북 파일명 포함 (예: "Playbook: alb-target-5xx.md")

### 알람 정의 (매트릭스 → Terraform 매핑)

| # | 알람 키 | Namespace | MetricName | Dimensions | Statistic | Threshold | Period | Eval | M-of-N | Missing Data | Severity |
|---|---------|-----------|------------|------------|-----------|-----------|--------|------|--------|--------------|----------|
| 1 | cloudfront_5xx | AWS/CloudFront | 5xxErrorRate | DistributionId | Average | 5 | 300 | 3 | 2 | notBreaching | P1 |
| 2 | cloudfront_origin_latency | AWS/CloudFront | OriginLatency | DistributionId | Average | 2000 | 300 | 3 | 2 | notBreaching | P3 |
| 3 | waf_blocked_spike | AWS/WAFV2 | BlockedRequests | WebACL,Rule | Sum | 1000 | 300 | 3 | 2 | notBreaching | P3 |
| 4 | alb_elb_5xx | AWS/ApplicationELB | HTTPCode_ELB_5XX_Count | LoadBalancer | Sum | 10 | 300 | 1 | 1 | notBreaching | P1 |
| 5 | alb_target_5xx | AWS/ApplicationELB | HTTPCode_Target_5XX_Count | LoadBalancer,TargetGroup | Sum | 50 | 300 | 1 | 1 | notBreaching | P2 |
| 6 | alb_unhealthy_host | AWS/ApplicationELB | UnHealthyHostCount | LoadBalancer,TargetGroup | Maximum | 1 | 300 | 1 | 1 | breaching | P1 |
| 7 | ecs_running_task_low | AWS/ECS | RunningTaskCount | ClusterName,ServiceName | Minimum | (desired-1) | 300 | 1 | 1 | breaching | P1 |
| 8 | ecs_cpu_high | AWS/ECS | CPUUtilization | ClusterName,ServiceName | Average | 80 | 300 | 3 | 3 | notBreaching | P3 |
| 9 | ecs_memory_high | AWS/ECS | MemoryUtilization | ClusterName,ServiceName | Average | 85 | 300 | 2 | 2 | notBreaching | P2 |
| 10 | aurora_connections_high | AWS/RDS | DatabaseConnections | DBClusterIdentifier | Average | 800 | 300 | 3 | 2 | notBreaching | P2 |
| 11 | aurora_freeable_memory_low | AWS/RDS | FreeableMemory | DBClusterIdentifier | Average | 524288000 | 300 | 3 | 3 | notBreaching | P2 |
| 12 | aurora_free_storage_low | AWS/RDS | FreeLocalStorage | DBClusterIdentifier | Average | 5368709120 | 300 | 3 | 3 | notBreaching | P2 |
| 13 | lambda_errors_high | AWS/Lambda | Errors | FunctionName | Sum | 10 | 300 | 1 | 1 | notBreaching | P2 |
| 14 | lambda_throttles_high | AWS/Lambda | Throttles | FunctionName | Sum | 10 | 300 | 3 | 2 | notBreaching | P2 |
| 15 | s3_5xx | AWS/S3 | 5xxErrors | BucketName,FilterId | Sum | 5 | 300 | 3 | 2 | notBreaching | P3 |
| 16 | cloudtrail_stop | custom | CloudTrailStopped | (none) | Sum | 1 | 300 | 1 | 1 | breaching | P1 |

### 참고: CloudTrail 알람
CloudTrail StopLogging은 네이티브 메트릭이 없다. CloudTrail → CloudWatch Logs → Metric Filter → 커스텀 메트릭 경로가 필요하다.
이 단계에서는 커스텀 메트릭이 이미 존재한다고 가정하고 알람만 정의한다.

### 태깅 표준

모든 리소스에 적용:
```hcl
tags = {
  Project     = var.project        # "msp-monitoring"
  Environment = var.environment    # "dev"
  ManagedBy   = "terraform"
  Service     = (알람별 서비스명)
  Severity    = (알람별 심각도)
}
```

## 구현 규칙

- terraform-aws-modules는 CloudWatch 알람에 적합한 공식 모듈이 없으므로 `aws_cloudwatch_metric_alarm` 리소스 직접 사용
- `for_each` 사용, `count` 사용 금지
- 변수에 기본값 제공하되, dimensions는 환경별로 반드시 override
- terraform fmt, terraform validate 통과해야 함
- 주석 최소화 (변수 description으로 설명)

## dimensions 예시 (terraform.tfvars.example)

```hcl
region      = "ap-northeast-2"
project     = "msp-monitoring"
environment = "dev"

alert_email = "ops-team@example.com"

# 각 알람의 dimensions는 alarms.auto.tfvars에서 override
# 예시:
# cloudfront_distribution_id = "E1234567890"
# alb_arn_suffix             = "app/my-alb/1234567890"
# target_group_arn_suffix    = "targetgroup/my-tg/1234567890"
# ecs_cluster_name           = "my-cluster"
# ecs_service_name           = "my-service"
# aurora_cluster_id          = "my-aurora-cluster"
# lambda_function_name       = "my-function"
# s3_bucket_name             = "my-bucket"
# waf_webacl_name            = "my-webacl"
```
