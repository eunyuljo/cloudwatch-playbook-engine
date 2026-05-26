# 실습 회고: Claude + Codex 협업으로 AWS MSP Runbook 자동화 구축

## 목표

Claude Code와 Codex를 적절히 나눠 써서 효과적인 결과물을 만드는 과정을 체험한다.

## 결과물

- GitHub: https://github.com/eunyuljo/cloudwatch-playbook-engine
- CloudWatch 알람 16개 (Terraform)
- Runbook Lambda 엔진 (Python, ALB Target 5xx 자동 진단)
- Slack Block Kit 연동

## 진행 타임라인

| 단계 | 작업 | 도구 | 커밋 |
|------|------|------|------|
| 1 | 스펙 설계 + Terraform 알람 구현 | Claude Code | `d3581cf` |
| 1.5 | Codex CLI로 코드 개선 (validation, 태깅) | Codex CLI (별도 터미널) | - |
| 1.5 | Codex 플러그인 리뷰 → 수정 반영 | Codex 플러그인 + Claude Code | `3b5603d` |
| 2 | Runbook Lambda 설계 + 구현 + 리뷰 반영 | Claude Code + Codex 플러그인 | `4e16337` |
| 3 | Slack 연동 | Claude Code | `99d636f` |

## AI 도구별 역할 정리

| 도구 | 실제 사용한 역할 | 적합도 |
|------|-----------------|--------|
| Claude Code | 설계, 스펙 작성, 코드 구현, 리뷰 반영 | 만능 — 대화가 필요한 모든 작업 |
| Codex CLI | 기존 코드 개선 (별도 터미널에서 직접 실행) | 구현/개선 — 단 TTY 필요 |
| Codex 플러그인 (rescue) | 코드 리뷰, 문제점 발견 | 리뷰/진단 전용 — 구현 위임은 불안정 |

## 발견한 한계와 교훈

### Codex 위임 실패 경험

| 시도 | 결과 | 원인 |
|------|------|------|
| Agent로 codex:rescue에 파일 생성 위임 | 디렉터리만 생성 | 간접 호출(3단계) 불안정 |
| `! codex` (Claude Code 내부) | stdin is not a terminal | Codex CLI는 TTY 필요 |
| 별도 터미널에서 codex 직접 실행 | 정상 동작 | 직접 실행이 유일한 안정 경로 |

### 핵심 교훈

1. **스펙 품질 = 구현 품질** — SPEC.md를 상세하게 쓸수록 결과가 좋았음
2. **도구는 용도대로** — Codex 플러그인은 리뷰용, 구현은 CLI 직접 또는 Claude Code
3. **독립 리뷰의 가치** — 다른 모델(GPT)이 보면 놓친 점이 보임 (무한 루프, IAM 과잉)
4. **실패도 학습** — 위임 실패 → fallback → 다음에 더 나은 경로 선택

## 아키텍처

```
CloudWatch Alarm (16개)
  → SNS(P1P2) → Lambda(Runbook Engine)
                   ├── 플레이북 라우팅
                   ├── ALB Target 5xx 자동 진단
                   │   ├── describe-target-health
                   │   ├── describe-services (ECS)
                   │   └── filter-log-events
                   ├── 의사결정 트리 판정
                   ├── SNS(Results) → Email
                   └── Slack Webhook → Block Kit 메시지
```

## Codex 리뷰가 잡아준 것들

- SNS 토픽 암호화 누락
- WAF 디멘션 이름 오류 (WebACL → WebACLName)
- SNS → Lambda 무한 루프 위험
- insufficient_data_actions 미설정
- IAM 미사용 권한 포함

## 다음에 할 수 있는 것

- `terraform apply`로 실제 배포
- 테스트 알람 트리거 → Slack 메시지 확인
- 플레이북 추가 (ECS task count low, Aurora connections)
- Secrets Manager로 webhook URL 관리
- 단위 테스트 추가
