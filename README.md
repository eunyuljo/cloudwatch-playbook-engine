# CloudWatch Playbook Engine

AWS MSP 운영 자동화 — CloudWatch 알람 발생 시 플레이북 기반 자동 진단을 실행하고 Slack으로 결과를 전송하는 시스템.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AWS Account                                        │
│                                                                                 │
│  ┌──────────────────┐                                                           │
│  │   ECS Fargate    │                                                           │
│  │  ┌────────────┐  │         ┌─────────────────┐                               │
│  │  │  nginx     │  │───────▶│       ALB       │◀──── 사용자 트래픽              │
│  │  │ container  │  │         │  (Load Balancer) │                              │
│  │  └────────────┘  │         └────────┬────────┘                               │
│  └──────────────────┘                  │                                        │
│                                        │ Health Check                           │
│                                        ▼                                        │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                         CloudWatch                                       │   │
│  │                                                                          │   │
│  │   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐  │   │
│  │   │ ALB 5xx     │   │ Unhealthy   │   │ ECS Task    │   │ ECS CPU     │  │   │
│  │   │ Count > 10  │   │ Host >= 1   │   │ Count < 1   │   │ > 80%       │  │   │
│  │   │ (P1)        │   │ (P1)        │   │ (P1)        │   │ (P3)        │  │   │
│  │   └──────┬──────┘   └──────┬──────┘   └──────┬──────┘   └──────┬──────┘  │   │
│  │          │                 │                 │                 │         │   │
│  └──────────┼─────────────────┼─────────────────┼─────────────────┼─────────┘   │
│             │ ALARM!          │ ALARM!          │ ALARM!          │ ALARM!       │
│             ▼                 ▼                 ▼                 │              │
│  ┌────────────────────────────────────────────────┐               │              │
│  │          SNS Topic: msp-alerts-p1p2            │               │              │
│  │          (긴급: P1, P2 알람)                    │               │              │
│  └───────┬──────────────────────┬─────────────────┘               │              │
│          │                      │                                 ▼              │
│          │                      │                  ┌──────────────────────────┐  │
│          │                      │                  │ SNS Topic: msp-alerts-   │  │
│          │                      │                  │ p3p4 (비긴급: P3, P4)     │  │
│          │                      │                  └────────────┬─────────────┘  │
│          │                      │                               │               │
│          ▼                      ▼                               ▼               │
│  ┌──────────────┐      ┌──────────────┐               ┌──────────────┐         │
│  │   Lambda     │      │    Email     │               │    Email     │         │
│  │  (Runbook    │      │  (운영자)     │               │  (운영자)     │         │
│  │   Engine)    │      └──────────────┘               └──────────────┘         │
│  └──────┬───────┘                                                               │
│         │                                                                       │
└─────────┼───────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        Lambda 내부 처리 흐름                                      │
│                                                                                 │
│  ┌─────────┐     ┌──────────┐    ┌─────────────────┐     ┌────────────────────┐  │
│  │ handler │── ▶ │  utils   │──▶│ PlaybookRegistry│───▶│ AlbTarget5xx       │  │
│  │  .py    │     │  .py     │    │ (__init__.py)   │     │ Playbook           │ │
│  │         │     │          │    │                 │     │                    │ │
│  │ 필터링   │     │ 키 추출   │    │ 플레이북 매칭     │     │ 진단 실행           │ │
│  └─────────┘     └──────────┘    └─────────────────┘     └────────┬───────────┘ │
│                                                                │               │
│                                                                ▼               │
│                                                    ┌───────────────────────┐   │
│                                                    │   AWS API 호출         │   │
│                                                    │                       │   │
│                                                    │ 1. describe-target-   │   │
│                                                    │    health             │   │
│                                                    │ 2. describe-services  │   │
│                                                    │ 3. filter-log-events  │   │
│                                                    └───────────┬───────────┘   │
│                                                                │               │
│                                                                ▼               │
│                                                    ┌───────────────────────┐   │
│                                                    │   _evaluate()         │   │
│                                                    │   의사결정 트리          │   │
│                                                    │                       │   │
│                                                    │ 전멸? → P1            │   │
│                                                    │ 일부? → P2            │   │
│                                                    │ 앱에러? → P2          │   │
│                                                    └───────────┬───────────┘   │
│                                                                │               │
│                                                                ▼               │
│                                                    ┌───────────────────────┐   │
│                                                    │   DiagnosisResult     │   │
│                                                    │   (표준 진단서)         │   │
│                                                    └───────────┬───────────┘   │
│                                                                │               │
│  ┌─────────────────────────────────────────────────────────────┘               │
│  │                                                                             │
│  ▼                                                                             │
│  ┌────────────────────────────────────────────────────┐                        │
│  │                  Notifier                          │                        │
│  │                                                    │                        │
│  │  ┌──────────────────┐    ┌──────────────────────┐ │                        │
│  │  │  SNS Publish     │    │  Slack Webhook       │ │                        │
│  │  │  (Email 발송)     │    │  (Block Kit 메시지)   │ │                        │
│  │  └────────┬─────────┘    └──────────┬───────────┘ │                        │
│  └───────────┼──────────────────────────┼─────────────┘                        │
│              │                          │                                      │
└──────────────┼──────────────────────────┼──────────────────────────────────────┘
               │                          │
               ▼                          ▼
       ┌──────────────┐          ┌──────────────────┐
       │  Email 수신   │          │   Slack 채널      │
       │  (운영팀)     │          │                  │
       └──────────────┘          │  🔴 P1 Alert     │
                                 │  Verdict: ALL_   │
                                 │  TARGETS_UNHEALTHY│
                                 │  ...             │
                                 └──────────────────┘
```


```
CloudWatch Alarm (6+ alarms)
  → SNS Topic (P1/P2)
    → Lambda (Runbook Engine)
      ├── Playbook Routing (alarm_key 기반)
      ├── Auto Diagnosis
      │   ├── ELB: describe-target-health
      │   ├── ECS: describe-services
      │   └── Logs: filter-log-events
      ├── Decision Tree (severity 판정)
      ├── SNS (Runbook Results) → Email
      └── Slack Webhook → Block Kit Message
```

## Scenario

MSP 운영팀이 고객의 웹 애플리케이션(ECS Fargate + ALB)을 24x7 모니터링하는 상황을 가정합니다.

**알람 발생 시:**
1. Lambda가 자동으로 초기 진단을 실행
2. 의사결정 트리로 심각도를 판정 (P1 승격 여부 등)
3. Slack에 구조화된 진단 리포트 전송
4. 운영자는 Slack만 보고 즉시 상황 파악 + 에스컬레이션 판단

### 판정 예시

| Verdict | 조건 | 대응 |
|---------|------|------|
| `ALL_TARGETS_UNHEALTHY` | 전체 타겟 비정상 | P1 승격, 즉시 에스컬레이션 |
| `PARTIAL_TARGETS_UNHEALTHY` | 일부 타겟 비정상 | 배포 확인, 롤백 여부 문의 |
| `TARGETS_HEALTHY_APP_ERROR` | 타겟 정상인데 5xx 지속 | 앱 팀에 로그 증거 첨부하여 에스컬레이션 |

## Project Structure

```
├── guide/                          # MSP 운영 가이드 (문서)
│   ├── 01-operating-scope.md       # 운영 범위
│   ├── 02-monitoring-matrix.md     # 모니터링 매트릭스
│   ├── 03-severity-escalation.md   # 심각도/에스컬레이션 정책
│   └── 04-playbook-alb-target-5xx.md  # ALB Target 5xx 플레이북
│
├── infra/                          # Terraform (모니터링 인프라)
│   ├── main.tf                     # Provider + 모듈 호출
│   ├── alarms.auto.tfvars          # 알람 정의 데이터
│   ├── modules/
│   │   ├── sns/                    # SNS 토픽 (P1P2, P3P4, Results)
│   │   ├── alarms/                 # CloudWatch 알람 (for_each)
│   │   └── runbook/                # Lambda + IAM + DLQ
│   └── test-env/                   # 테스트용 최소 인프라 (VPC+ALB+ECS)
│
├── lambda/runbook_engine/          # Lambda 코드 (Python 3.12)
│   ├── handler.py                  # 진입점, 라우팅
│   ├── playbooks/
│   │   ├── base.py                 # 추상 클래스
│   │   └── alb_target_5xx.py       # ALB Target 5xx 진단
│   ├── notifier.py                 # SNS + Slack 발송
│   └── utils.py                    # 알람 키 추출
│
├── docs/lab-retrospective.md       # 실습 회고
└── SPEC.md                         # 구현 스펙 (설계 문서)
```

## Quick Start

### Prerequisites

- Terraform >= 1.5
- AWS CLI configured
- Slack Incoming Webhook URL

### 1. Deploy Test Infrastructure

```bash
cd infra/test-env
terraform init && terraform apply
```

### 2. Deploy Monitoring Stack

```bash
cd infra

# terraform.tfvars에 실제 값 입력
cat > terraform.tfvars <<EOF
region      = "ap-northeast-2"
project     = "msp-monitoring"
environment = "dev"
alert_email = "your-email@example.com"
slack_webhook_url = "https://hooks.slack.com/services/..."
ecs_cluster_name   = "msp-monitoring-test-cluster"
ecs_service_name   = "msp-monitoring-test-app"
app_log_group_name = "/ecs/msp-monitoring-test/app"
target_group_arn   = "<from test-env output>"
EOF

terraform init && terraform apply
```

### 3. Trigger Test Alarm

```bash
# Health check를 일부러 실패시켜서 알람 유발
cd infra/test-env
terraform apply -var='health_check_matcher=201'

# 2~3분 후 Slack에 진단 결과 메시지 수신
```

### 4. Restore & Cleanup

```bash
cd infra/test-env && terraform apply -var='health_check_matcher=200'
cd infra/test-env && terraform destroy
cd infra && terraform destroy
```

## Verified E2E Flow

실제 AWS 배포 후 검증 완료:

```
CloudWatch: UnHealthyHostCount >= 1 (ALARM)
  → SNS: Successfully executed action
    → Lambda: Processing alarm (key: alb_unhealthy_host)
      → describe-target-health: 1/1 unhealthy, reason: Target.ResponseCodeMismatch
      → describe-services: desired=1, running=1
      → Verdict: ALL_TARGETS_UNHEALTHY
        → Slack: 🔴 P1 진단 리포트 수신 ✅
```

## AI-Assisted Development

이 프로젝트는 Claude Code + Codex 협업으로 구축되었습니다.

| 도구 | 역할 |
|------|------|
| Claude Code | 설계, 스펙 작성, 코드 구현, 리뷰 반영 |
| Codex CLI | 코드 개선 (validation, 태깅 보강) |
| Codex Plugin | 코드 리뷰 (보안, 운영 안정성 피드백) |

상세 회고: [docs/lab-retrospective.md](docs/lab-retrospective.md)

## Cost

| Resource | Approximate Cost |
|----------|-----------------|
| ALB (test only) | ~$0.023/hour |
| Fargate SPOT | ~$0.005/hour |
| CloudWatch Alarms | $0.10/alarm/month |
| Lambda, SNS, SQS | Free tier |

테스트 후 `terraform destroy`로 즉시 정리 가능.

## License

MIT
