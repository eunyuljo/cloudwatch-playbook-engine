# CloudWatch Playbook Engine — 학습 가이드

## 이 프로젝트를 한마디로

> 서버에 문제가 생기면, 사람 대신 자동으로 "뭐가 잘못됐는지" 확인하고 Slack으로 알려주는 시스템

병원 비유로 생각하면:
- **CloudWatch Alarm** = 환자 모니터의 경고음 (혈압 이상!)
- **SNS** = 간호사 호출 시스템 (누구에게 알릴지 분배)
- **Lambda** = 당직 의사 (증상 확인 → 진단 → 처방전 작성)
- **Slack** = 의사가 작성한 진단서를 팀 채팅방에 공유

---

## 왜 이렇게 구성했는가? (아키텍처 결정 이유)

### Q: 왜 Lambda인가? EC2에 데몬 돌리면 안 되나?

| | Lambda | EC2 데몬 |
|--|--------|----------|
| 비용 | 알람 올 때만 과금 (월 수십원) | 24시간 켜놔야 함 (월 수만원) |
| 관리 | 서버 관리 불필요 | OS 패치, 모니터링 필요 |
| 확장성 | 자동으로 동시 실행 | 직접 스케일링 구현 |
| 적합성 | "이벤트 올 때만 잠깐 실행" = Lambda의 정확한 용도 | 상시 실행 워크로드에 적합 |

**결론:** 알람은 하루에 몇 건 안 옴. 24시간 서버 띄워놓는 건 낭비.

### Q: 왜 SNS를 중간에 끼웠나? CloudWatch → Lambda 직접 연결하면 안 되나?

직접 연결도 가능하지만, SNS를 끼우면:

1. **팬아웃 (Fan-out):** 하나의 알람을 여러 수신자에게 동시에 보낼 수 있음
   - Lambda (자동 진단)
   - Email (사람에게 직접)
   - 나중에 PagerDuty, Teams 추가도 SNS subscription만 추가하면 끝

2. **심각도 라우팅:** P1P2 토픽과 P3P4 토픽을 분리해서 "긴급한 건 자동 진단, 덜 급한 건 이메일만" 가능

3. **결합도 낮춤:** CloudWatch는 "SNS에 보내면 끝". 뒤에 뭐가 붙든 CloudWatch는 수정 불필요.

### Q: 왜 Terraform 모듈을 3개로 나눴나? main.tf에 다 쓰면 안 되나?

**파일 하나에 다 쓰면:**
- 200줄 넘어가면 읽기 힘듦
- SNS 하나 고치려다 알람 설정 실수로 건드릴 수 있음
- 팀원이 동시에 같은 파일 수정하면 충돌

**모듈로 나누면:**
- `modules/sns/` = "알림 채널 담당자"
- `modules/alarms/` = "알람 조건 담당자"
- `modules/runbook/` = "Lambda 담당자"
- 각자 독립적으로 수정 가능. 인터페이스(input/output)만 맞으면 됨.

### Q: 왜 플레이북을 추상 클래스로 만들었나? 그냥 if문 쓰면 안 되나?

**if문으로 했다면:**

```python
# handler.py가 점점 비대해짐
if alarm_key == "alb_unhealthy_host":
    # 진단 로직 50줄...
elif alarm_key == "ecs_task_low":
    # 진단 로직 50줄...
elif alarm_key == "rds_connections":
    # 진단 로직 50줄...
# → 파일 하나에 500줄, 수정할 때마다 전체에 영향
```

**추상 클래스로 하면:**

```python
# 각 플레이북이 독립 파일
# handler.py는 영원히 50줄
# 새 플레이북 추가해도 기존 코드 안 건드림
```

### Q: 왜 `alarms.auto.tfvars`에 데이터를 분리했나? main.tf에 직접 쓰면 안 되나?

**코드에 직접 쓰면:**
```hcl
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  threshold = 10
  ...
}
resource "aws_cloudwatch_metric_alarm" "ecs_cpu" {
  threshold = 80
  ...
}
# → 알람 20개 = 리소스 블록 20개 = 500줄
```

**데이터로 분리하면:**
```hcl
# alarms.auto.tfvars (데이터만)
alarms = { alb_5xx = {...}, ecs_cpu = {...} }

# main.tf (코드는 1개)
resource "..." { for_each = var.alarms }
# → 알람 100개여도 코드는 그대로 10줄
```

**운영 관점:** "threshold를 10에서 20으로 바꿔줘" → tfvars 파일에서 숫자 하나만 변경. Terraform 코드 이해할 필요 없음.

### Q: 왜 DLQ를 붙였나? 실패하면 그냥 다시 시도하면 되지 않나?

Lambda는 기본적으로 2번 재시도함. 그래도 실패하면?

**DLQ 없으면:** 메시지 사라짐 → 새벽에 알람 왔는데 아무도 모름 → 장애 확대
**DLQ 있으면:** 14일간 보관 → 아침에 출근해서 "어젯밤에 이거 처리 못 했구나" 확인 가능

### Q: 왜 `reserved_concurrent_executions = 5`로 제한했나?

서버 50대가 동시에 죽으면 알람 50개가 한꺼번에 옴. Lambda 50개가 동시에 AWS API 호출하면:
- API rate limit에 걸림 (throttling)
- 진단 자체가 전부 실패
- DLQ에 50개가 쌓임

5개로 제한하면: 차례로 처리 → API 안정적 → 결과도 안정적.

---

## 학습 목표

1. **AWS 서버리스 이벤트 아키텍처** — CloudWatch → SNS → Lambda 파이프라인
2. **Terraform 모듈화** — for_each, auto.tfvars, 모듈 간 output 체이닝
3. **플레이북 기반 운영 자동화** — 진단 → 판정 → 알림 패턴
4. **MSP 운영 실무** — 심각도 체계, 에스컬레이션 정책, 의사결정 트리

---

## 전체 아키텍처

```
[감시]  CloudWatch가 서버 상태를 계속 지켜봄
         ↓ 이상 감지!
[분배]  SNS가 "긴급이면 Lambda한테, 덜 급하면 이메일만"
         ↓ 긴급 알람 도착
[진단]  Lambda가 AWS API를 호출해서 상태 확인
         ↓ 결과 정리
[판정]  "전부 죽었네 → P1" or "일부만 → P2" 심각도 결정
         ↓
[알림]  Slack + Email로 진단서 발송
```

실제 코드에서는:

```
CloudWatch Alarm (6개 알람)
  → SNS Topic (심각도별 라우팅: P1P2 / P3P4)
    → Lambda (Runbook Engine) 트리거
      ├── 알람 키 추출 (utils.py)
      ├── 플레이북 매칭 (PlaybookRegistry)
      ├── 자동 진단 (AWS API 호출)
      │   ├── ELB: describe-target-health
      │   ├── ECS: describe-services
      │   └── Logs: filter-log-events
      ├── 의사결정 트리 → Verdict 판정
      └── 결과 발송
          ├── SNS (runbook-results) → Email
          └── Slack Webhook → Block Kit Message
```

---

## Part 1: Terraform 인프라

> Terraform = "AWS에 뭘 만들지 적어놓는 설계도". `terraform apply`를 실행하면 설계도대로 리소스가 생성됨.

### 1-1. 진입점 — `infra/main.tf`

**비유:** 건물의 "전체 평면도". 각 방(모듈)이 어디에 있고, 배관(데이터)이 어떻게 연결되는지 한눈에 보여줌.

이 파일 자체는 리소스를 직접 만들지 않고, 3개 모듈을 호출하면서 "이 값 써서 만들어"라고 지시한다:

```hcl
module "sns"     → "알림 채널 만들어" (이메일 주소 줄게)
module "alarms"  → "알람 만들어" (sns가 만든 토픽 ARN 줄게)
module "runbook" → "Lambda 만들어" (sns가 만든 토픽 ARN + 진단 대상 정보 줄게)
```

**모듈 간 데이터 흐름:**

```
module.sns (먼저 생성됨)
  ├─ output: topic_arn_p1p2 ──→ module.alarms에 전달 (알람이 울리면 여기로 보내)
  ├─ output: topic_arn_p1p2 ──→ module.runbook에 전달 (이 토픽을 구독해)
  ├─ output: topic_arn_p3p4 ──→ module.alarms에 전달
  └─ output: topic_arn_runbook_results ──→ module.runbook에 전달 (진단 결과는 여기로)
```

**핵심 개념:**
- Terraform 모듈은 **output**으로 값을 내보내고, 호출자가 다른 모듈의 **variable**에 주입
- 이렇게 하면 모듈 간 의존성이 명시적으로 드러남
- Terraform이 자동으로 "sns 먼저 만들고 → 나머지" 순서를 결정

---

### 1-2. SNS 모듈 — `infra/modules/sns/`

**비유:** 병원의 "호출 시스템". 긴급 호출 채널, 일반 호출 채널, 결과 전달 채널을 만듦.

**역할:** 메시지를 받아서 적절한 수신자에게 전달하는 우체통 3개를 만든다.

| 토픽 (우체통) | 누가 메시지를 넣나 | 누가 받나 |
|---------------|-------------------|-----------|
| `msp-alerts-p1p2` | CloudWatch 알람 (긴급) | Lambda + Email |
| `msp-alerts-p3p4` | CloudWatch 알람 (비긴급) | Email만 |
| `msp-runbook-results` | Lambda (진단 결과) | Email |

**왜 토픽을 나눴나?**
- P1/P2 (긴급): Lambda가 자동 진단 → 새벽에도 자동으로 1차 대응
- P3/P4 (비긴급): 이메일만 → 다음 날 업무시간에 확인

**관련 AWS 개념:**
- SNS Topic = 우체통. 누구나 메시지를 넣을 수 있음
- SNS Subscription = 우체통에서 편지를 받는 사람 등록. protocol으로 수단 결정 (email, lambda, sqs 등)

---

### 1-3. Alarms 모듈 — `infra/modules/alarms/`

**비유:** 병원의 "환자 모니터 설정". "혈압이 180 넘으면 경고음 울려" 같은 조건들을 정의.

**역할:** "어떤 메트릭이 몇 이상이면 알람을 울릴지" 조건을 정의하고, 알람이 울리면 어떤 SNS 토픽에 보낼지 결정.

```hcl
resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = var.alarms   # ← 알람 목록을 순회하면서 하나씩 생성

  alarm_name = "${var.project}-${var.environment}-${each.key}"
  # 예: "msp-monitoring-dev-alb_unhealthy_host"

  # 알람이 울리면 어디로?
  alarm_actions = contains(["P1", "P2"], each.value.severity)
    ? [var.sns_topic_arn_p1p2]    # 긴급 → Lambda 가동
    : [var.sns_topic_arn_p3p4]    # 비긴급 → 이메일만
}
```

**`for_each`가 뭔가?**

알람을 하나하나 따로 쓰는 대신, 목록(map)을 주면 자동으로 반복 생성:

```
없이: alarm_a {...}  alarm_b {...}  alarm_c {...}  ← 중복 코드 범벅
있으면: for_each = {a, b, c} → 3개 자동 생성    ← 데이터만 관리
```

**알람 파라미터 이해 (체온 비유):**

| 파라미터 | 비유 | 실제 |
|----------|------|------|
| `threshold` | "38도 이상이면" | 임계치 |
| `period` | "5분마다 체온 측정" | 메트릭 집계 주기 (초) |
| `evaluation_periods` | "3번 연속 측정" | 몇 회 평가할지 |
| `datapoints_to_alarm` | "그 중 2번 이상 38도면 경고" | M-of-N |
| `treat_missing_data` | "체온계가 고장나면?" | 데이터 없을 때 동작 |

**`treat_missing_data` — 데이터가 안 오면?**
- `notBreaching` = "측정 안 되면 정상으로 간주" (대부분의 경우)
- `breaching` = "측정 안 되면 비정상으로 간주" (UnHealthyHostCount — 데이터가 안 오면 서버 자체가 죽은 것일 수 있으니)

---

### 1-4. 알람 데이터 — `infra/alarms.auto.tfvars`

**비유:** "환자 모니터 설정 목록". 어떤 환자의 어떤 수치를 감시할지 적어놓은 표.

```hcl
alarms = {
  alb_unhealthy_host = {
    metric_name = "UnHealthyHostCount"   # "비정상 서버 수"를 감시
    threshold   = 1                       # 1개라도 비정상이면
    period      = 60                      # 1분마다 확인
    severity    = "P1"                    # 긴급!
    dimensions = {                        # 어떤 서버를 볼 건지
      LoadBalancer = "app/msp-monitoring-test-alb/..."
      TargetGroup  = "targetgroup/msp-monitoring-test-tg/..."
    }
  }
}
```

**핵심:**
- `.auto.tfvars` — Terraform이 자동으로 읽어가는 파일. 별도 옵션 불필요.
- 새 알람 추가하려면? 이 파일에 블록 하나 추가하고 `terraform apply`. 끝.
- 알람 key (`alb_unhealthy_host`)가 나중에 Python에서 플레이북을 찾는 키로 사용됨.

---

### 1-5. Runbook 모듈 — `infra/modules/runbook/`

**비유:** "당직 의사를 고용하고, 진찰실 세팅하고, 호출 시스템에 연결하는 것" 전부를 한 번에.

**역할:** Lambda 함수(=당직 의사)가 작동하려면 필요한 모든 것을 세팅한다.

```
Lambda 함수 (당직 의사)
├── IAM Role + Policy (신분증 + 권한)
│   → "진찰은 할 수 있지만, 수술은 못 해" (읽기만 가능)
├── SNS Subscription (호출 등록)
│   → "긴급 호출이 오면 이 의사에게 연결해"
├── Lambda Permission (호출 허가)
│   → "간호사(SNS)가 이 의사를 호출해도 된다"
├── CloudWatch Log Group (진료 기록부)
│   → 30일 보관
└── SQS DLQ (미처리 환자 대기실)
    → 진단 실패한 건 14일간 보관해둠
```

**핵심 포인트들:**

**① Terraform → Python 연결 (환경변수)**

```hcl
environment {
  variables = {
    TARGET_GROUP_ARN   = var.target_group_arn
    ECS_CLUSTER_NAME   = var.ecs_cluster_name
    SLACK_WEBHOOK_URL  = var.slack_webhook_url
  }
}
```

Terraform이 "어떤 서버를 진단할지" 정보를 환경변수로 Lambda에 전달.
Python에서는 `os.environ["TARGET_GROUP_ARN"]`으로 읽음.

**② SNS → Lambda 연결에 왜 2개가 필요한가?**

실생활 비유: 택배 배송
- `sns_topic_subscription` = 배송 업체에 "이 주소로 보내줘" 등록
- `lambda_permission` = 집주인이 "택배 아저씨가 문 앞에 놔둬도 돼" 허락

양쪽 다 동의해야 배달 완료. AWS도 마찬가지.

**③ DLQ (Dead Letter Queue) — 왜 필요한가?**

Lambda가 처리 실패하면 메시지가 사라짐 → 알람이 왔는데 아무도 모름!
DLQ에 보관하면 → "아 어제 밤에 이 알람 처리 못 했구나" 나중에 확인 가능.

**④ `reserved_concurrent_executions = 5`**

서버 100대가 동시에 죽으면 알람 100개가 한꺼번에 옴.
100개 Lambda가 동시에 돌면 AWS API 호출 제한에 걸림.
5개로 제한하면 차례로 처리 → 안정적.

---

## Part 2: Lambda 코드 (Python)

> 지금부터는 Terraform이 만든 Lambda 안에서 돌아가는 **실제 코드**를 본다.
> 비유: Terraform은 "진찰실을 만드는" 역할, Python은 "진찰을 하는" 역할.

### 2-1. 진입점 — `lambda/runbook_engine/handler.py`

**비유:** 병원 접수처. 환자(알람)가 오면 "진짜 환자인지 확인하고, 맞는 진료실(플레이북)로 보내주는" 역할.

#### 이 함수는 "언제" 호출되나?

```
CloudWatch 알람 울림
  → SNS 토픽에 메시지 게시
    → SNS가 Lambda를 호출하면서 이벤트를 넘겨줌
      → lambda_handler(event, context) 실행됨
```

#### `event`는 어떻게 생겼나?

SNS가 Lambda에 넘기는 이벤트 — 편지 봉투라고 생각하면 됨:

```json
{
  "Records": [
    {
      "Sns": {
        "Subject": "ALARM: msp-monitoring-dev-alb_unhealthy_host ...",
        "Message": "{\"AlarmName\":\"msp-monitoring-dev-alb_unhealthy_host\", \"NewStateValue\":\"ALARM\", ...}"
      }
    }
  ]
}
```

- `Subject` = 봉투 겉면 (제목)
- `Message` = 봉투 안의 편지 (JSON 문자열 — 알람 상세 정보)
- `Records`가 리스트인 이유: 보통 1개씩 오지만 여러 개가 묶여올 수도 있어서

#### 줄별 해설

**Notifier 초기화:**

```python
def lambda_handler(event, context):
    notifier = Notifier(topic_arn=os.environ["NOTIFICATION_TOPIC_ARN"])
```

"결과를 보낼 우체통 주소를 준비해둠." Terraform이 환경변수로 넣어준 값.

**레코드 순회 + Subject 확인:**

```python
    for record in event["Records"]:
        try:
            sns_message = record["Sns"]
            subject = sns_message.get("Subject", "")
```

각 편지(레코드)를 하나씩 열어봄.

**필터 1 — 무한루프 방지:**

```python
            if subject.startswith(RUNBOOK_SUBJECT_PREFIX):  # "[Runbook]"
                logger.info("Skipping self-generated message: %s", subject)
                continue
```

왜 필요한가 — 최악의 시나리오:

```
1. 알람 → P1P2 토픽 → Lambda 실행
2. Lambda가 진단 결과를 SNS에 publish (Subject: "[Runbook] P1 - ...")
3. 그런데 Lambda도 P1P2 토픽을 구독 중!
4. 자기가 보낸 메시지가 다시 자기에게 옴
5. → 무한 반복! (비용 폭탄)
```

해결: 자기가 보낸 건 `[Runbook]`으로 시작하니까, 그걸 보면 "내가 보낸 거네" → skip.

(이 프로젝트에서는 결과를 별도 토픽(`runbook-results`)에 보내서 실제로는 안 일어나지만, 방어적으로 체크)

**필터 2 — JSON 파싱:**

```python
            message = json.loads(sns_message["Message"])
        except (json.JSONDecodeError, KeyError, TypeError) as e:
            logger.error("Failed to parse SNS message: %s", str(e))
            continue
```

편지 내용이 깨져있으면? → 로그 남기고 버림. 다음 편지로.

**필터 3 — 알람 메시지 확인:**

```python
        if not isinstance(message, dict) or "AlarmName" not in message:
            logger.info("Skipping non-alarm message")
            continue
```

SNS 토픽에는 알람 외에도 잡다한 메시지가 올 수 있음 (예: 구독 확인 메시지). 알람이 아니면 skip.

**필터 4 — ALARM 상태만 처리:**

```python
        if message.get("NewStateValue") != "ALARM":
            logger.info("Skipping non-ALARM state: %s", message.get("NewStateValue"))
            continue
```

CloudWatch 알람은 3가지 상태 변화를 알려줌:
- `ALARM` → "문제 발생!" (**이것만 진단**)
- `OK` → "문제 해결됨"
- `INSUFFICIENT_DATA` → "판단 불가"

정상 복구(OK) 메시지에 진단을 돌릴 필요 없으니 skip.

**알람 키 추출 + 플레이북 매칭:**

```python
        alarm_name = message["AlarmName"]
        alarm_key = extract_alarm_key(alarm_name)

        playbook = PlaybookRegistry.get(alarm_key)
        if playbook is None:
            notifier.send_no_playbook(alarm_name, message)
            continue
```

비유: "이 환자 증상에 맞는 매뉴얼이 있나?" → 없으면 "수동 대응 필요" 알림 보냄.

**플레이북 실행 + 결과 발송:**

```python
        try:
            result = playbook.run(message)
            notifier.send_diagnosis(result)
        except Exception as e:
            notifier.send_error(alarm_name, str(e))
```

매뉴얼대로 진단 실행. 성공하든 실패하든 **운영자에게 항상 뭔가는 전달됨:**
- 성공 → 진단 결과
- 실패 → "진단 자체가 실패했습니다" 알림

#### handler.py 전체 흐름 요약

```
이벤트 도착
  → [체크 1] 내가 보낸 메시지? → 무시
  → [체크 2] 파싱 안 됨? → 무시
  → [체크 3] 알람 아님? → 무시
  → [체크 4] 정상 복구 알림? → 무시
  → 플레이북 없음? → "수동 대응 필요" 알림
  → 플레이북 있음 → 진단 실행 → 결과 알림
  → 진단 에러? → "에러 발생" 알림
```

#### handler.py의 역할 한마디

> "접수처 직원 — 진짜 환자만 골라서, 맞는 진료실로 보내주는 사람"

직접 진단하지 않고, 직접 알림 보내지 않고, **라우팅만** 한다.

---

### 2-2. 유틸리티 — `lambda/runbook_engine/utils.py`

**비유:** "환자 이름에서 병동 번호 떼어내기"

Terraform이 알람 이름을 `프로젝트-환경-알람키` 형태로 만듦:

```
"msp-monitoring-dev-alb_unhealthy_host"
 └─ 프로젝트 ─┘└환경┘ └── 알람 키 ──┘
```

이 함수는 앞의 접두사를 벗기고 순수한 키만 추출:

```python
def extract_alarm_key(alarm_name: str) -> str:
    prefix = f"{project}-{environment}-"
    # "msp-monitoring-dev-alb_unhealthy_host"
    #  접두사 제거 → "alb_unhealthy_host"
    if alarm_name.startswith(prefix):
        return alarm_name[len(prefix):]
```

**왜 필요한가?**

```
Terraform 세계: "msp-monitoring-dev-alb_unhealthy_host" (충돌 방지용 full name)
Python 세계:    "alb_unhealthy_host" (짧은 키로 플레이북 매칭)
```

이 함수가 **두 세계의 번역기** 역할.

**fallback 로직:**
환경변수가 비어있거나 이름 형식이 다르면, 최후 수단으로 마지막 `-` 기준으로 잘라서 반환.

---

### 2-3. 플레이북 레지스트리 — `lambda/runbook_engine/playbooks/__init__.py`

**비유:** "진료실 안내판" — 증상(알람 키)을 보고 어느 진료실(플레이북)로 가야 할지 알려줌.

```python
_PLAYBOOKS = {}  # 안내판 (빈 상태로 시작)

def _register(playbook_class):
    instance = playbook_class()
    for key in instance.alarm_keys:
        _PLAYBOOKS[key] = instance  # "이 증상은 이 진료실로"

_register(AlbTarget5xxPlaybook)  # 등록!
```

등록 결과:

```python
_PLAYBOOKS = {
    "alb_target_5xx":     AlbTarget5xxPlaybook,  # 5xx 에러 → 이 플레이북
    "alb_unhealthy_host": AlbTarget5xxPlaybook,  # 타겟 비정상 → 같은 플레이북
}
```

**왜 하나의 플레이북이 키 2개를 처리?**

"5xx 에러"와 "타겟 비정상"은 원인이 비슷함 (서버 문제) → 같은 진단 방법으로 확인 가능.

**새 플레이북 추가하려면?**

```python
from .ecs_task_low import EcsTaskLowPlaybook
_register(EcsTaskLowPlaybook)  # 이 한 줄 추가하면 끝
```

---

### 2-4. 추상 클래스 — `lambda/runbook_engine/playbooks/base.py`

**비유:** "진단서 양식" — 모든 의사(플레이북)는 이 양식에 맞춰서 결과를 작성해야 함.

```python
@dataclass
class DiagnosisResult:
    alarm_name: str           # 무슨 알람이 울렸나
    severity: str             # 얼마나 급한가 (P1 = 매우 긴급)
    verdict: str              # 판정 (ALL_TARGETS_UNHEALTHY 등)
    summary: str              # 한 줄 요약 (사람이 읽음)
    details: dict             # 상세 데이터 (숫자들)
    recommended_action: str   # "이렇게 하세요" 권장 조치

class BasePlaybook(ABC):
    def run(self, alarm_message) -> DiagnosisResult   # 반드시 구현
    def alarm_keys -> list                             # 반드시 구현
```

**왜 이렇게 만들었나?**

- 진단서 양식이 통일되면, **누가 작성하든** 같은 형태 → Notifier(알림 발송)가 한 종류 코드로 모든 진단 결과를 처리 가능
- 새 플레이북 작성자는 "진단 로직"만 집중하면 됨. 알림 포맷은 신경 안 써도 됨.

---

### 2-5. 구체 플레이북 — `lambda/runbook_engine/playbooks/alb_target_5xx.py`

**비유:** "ALB/서버 문제 진단 매뉴얼" — 의사가 실제로 따르는 단계별 진찰 절차.

이 파일이 **프로젝트의 핵심 비즈니스 로직**. 실제로 AWS API를 호출해서 상태를 확인하는 코드.

#### Step 1: 데이터 수집 — "증상 확인"

| 뭘 확인하나 | AWS API 호출 | 알 수 있는 것 |
|------------|-------------|-------------|
| 서버가 살아있나? | `elbv2.describe_target_health` | healthy 2개, unhealthy 1개, 원인: 응답 코드 불일치 |
| 컨테이너는 잘 돌고 있나? | `ecs.describe_services` | desired=2, running=1, 배포 중인지 여부 |
| 에러 로그 뭐가 찍혔나? | `logs.filter_log_events` | 최근 5분간 ERROR 로그 20건 |

#### Step 2: 의사결정 트리 — "진단"

```
전체 서버 다 죽었나? (unhealthy == total)
  → 판정: ALL_TARGETS_UNHEALTHY (전멸)
  → 심각도: P1 (최고 긴급)
  → 권장: "즉시 에스컬레이션, 롤백 고려"

일부만 죽었나? (unhealthy > 0)
  → 판정: PARTIAL_TARGETS_UNHEALTHY
  → 심각도: P2
  → 배포 중이면? → "새로 배포한 게 문제일 수 있어요. 롤백할까요?"
  → 아니면?     → "모니터링 계속, 퍼지면 에스컬레이션"

서버는 다 살아있는데 5xx 에러?
  → 판정: TARGETS_HEALTHY_APP_ERROR
  → 심각도: P2
  → 권장: "앱 코드 문제. 개발팀에 로그 첨부해서 에스컬레이션"
```

**핵심:** 단순히 "문제 있음"이 아니라, **상황에 맞는 구체적 조치**를 제안함.

#### Step 3: 결과 반환

```python
return DiagnosisResult(
    alarm_name="msp-monitoring-dev-alb_unhealthy_host",
    severity="P1",
    verdict="ALL_TARGETS_UNHEALTHY",
    summary="All 2 targets are unhealthy.",
    details={"unhealthy_count": 2, "total_count": 2, "reasons": ["Target.FailedHealthChecks"]},
    recommended_action="Escalate to MSP L2 and customer app team immediately."
)
```

이게 Notifier로 전달되어 Slack + Email로 발송됨.

**실무 포인트:**
- 환경변수 `TARGET_GROUP_ARN`이 없으면? → 죽지 않고 `CONFIG_ERROR` verdict 반환
- 로그 조회 실패하면? → 나머지 진단은 계속 진행 (`available: False`로 표시)
- `has_active_deployment` 체크 — 배포 중이면 "방금 배포한 게 원인일 수 있다"고 맥락 제공

---

### 2-6. 알림 — `lambda/runbook_engine/notifier.py`

**비유:** "진단서를 환자 보호자에게 전달하는 간호사". 두 가지 방법으로 전달.

**역할:** `DiagnosisResult`를 받아서 2개 채널로 발송

```python
class Notifier:
    send_diagnosis(result)    # 정상 진단 결과 → SNS + Slack
    send_no_playbook(...)     # 매뉴얼 없음 → SNS + Slack
    send_error(...)           # 진단 실패 → SNS + Slack
```

**채널 1: SNS → Email (텍스트)**

```
[P1] msp-monitoring-dev-alb_unhealthy_host

Verdict: ALL_TARGETS_UNHEALTHY
Summary: All 2 targets are unhealthy.

Recommended Action: Escalate to MSP L2...
```

**채널 2: Slack → Block Kit (시각적)**

```
┌──────────────────────────────────────┐
│ 📋 P1 Alert - Runbook Diagnosis     │
│ 🔴 msp-monitoring-dev-alb_unhealthy │
│                                      │
│ Verdict: ALL_TARGETS_UNHEALTHY      │
│ Severity: P1                         │
│                                      │
│ Summary: All 2 targets unhealthy    │
│                                      │
│ Details:                             │
│ • unhealthy_count: 2                │
│ • reasons: [Target.FailedHealth...] │
│ ─────────────────────────────────── │
│ 👉 Escalate to MSP L2...           │
└──────────────────────────────────────┘
```

**심각도별 색깔:**
- P1: 🔴 빨강 — "지금 당장!"
- P2: 🟠 주황 — "빨리 확인"
- P3: 🟡 노랑 — "다음 업무시간에"

**중요한 설계 결정:**

1. **외부 라이브러리 안 씀:** `urllib.request`로 HTTP 호출. `requests` 설치 불필요 → Lambda 패키지 가벼움
2. **Slack 실패해도 죽지 않음:** `except URLError → logger.error` → SNS(이메일)는 정상 발송
3. **`[Runbook]` prefix:** Subject에 이걸 붙여서, handler.py가 자기 메시지를 인식하고 무한루프 방지

---

## Part 3: 테스트 인프라 (`infra/test-env/`)

**비유:** "진료 시스템이 잘 작동하는지 테스트하기 위한 가짜 환자"

알람 시스템을 검증하려면 "진짜로 문제가 발생하는 서버"가 필요함. 그래서 일부러 깨뜨릴 수 있는 최소 인프라를 만듦:

| 파일 | 리소스 | 비유 |
|------|--------|------|
| `vpc.tf` | VPC, Subnet, IGW | 병원 건물 (네트워크) |
| `alb.tf` | ALB, Target Group | 접수 창구 (로드 밸런서) |
| `ecs.tf` | Fargate Service (nginx 1개) | 의사 1명 (컨테이너) |
| `logs.tf` | Log Group | 진료 기록부 |

**E2E 테스트 — 일부러 문제 만들기:**

```bash
# 정상: health check가 200을 기대, nginx가 200 반환 → healthy
terraform apply -var='health_check_matcher=200'

# 문제 유발: health check가 201을 기대, nginx는 200 반환 → "어 201 아니잖아" → unhealthy
terraform apply -var='health_check_matcher=201'

# 2~3분 후:
# CloudWatch: "UnHealthyHostCount >= 1!" → ALARM
# SNS: Lambda에 알림 전달
# Lambda: 진단 실행 → "전체 타겟 비정상!"
# Slack: 🔴 P1 진단 리포트 수신
```

---

## Part 4: 설계 패턴 정리

### 패턴 1: 데이터 기반 리소스 관리 (Terraform)

```
alarms.auto.tfvars (데이터 = "뭘 감시할지 목록")
  → for_each (반복 = "목록대로 하나씩 만들어")
    → 알람 N개 생성
```

**장점:** 새 알람 추가 = 데이터에 줄 하나 추가. 코드 수정 없음.

### 패턴 2: Registry + Strategy (Python)

```
알람 키 → 안내판(Registry)에서 조회 → 맞는 플레이북 실행
```

**장점:** 새 진단 로직 추가 = 클래스 하나 작성 + 등록 한 줄. 기존 코드 수정 없음.

### 패턴 3: 진단 → 판정 → 알림 분리

```
Playbook (진단 = "뭐가 문제인지 확인")
  → DiagnosisResult (진단서 = "표준 양식으로 정리")
    → Notifier (발송 = "Slack이랑 이메일로 보내기")
```

**장점:**
- 플레이북은 "Slack이 뭔지" 몰라도 됨
- Notifier는 "ELB가 뭔지" 몰라도 됨
- 둘을 연결하는 건 `DiagnosisResult`라는 표준 양식 하나

### 패턴 4: 무한루프 방지

```
Lambda → SNS에 결과 보냄 → SNS가 다시 Lambda 호출 → ???
해결: Subject에 "[Runbook]" 붙여놓고, 그걸 보면 skip
```

### 패턴 5: Graceful Degradation (우아한 실패)

```
"하나가 실패해도 전체가 죽지 않는다"

설정 누락?      → CONFIG_ERROR라고 알려줌 (중단 안 함)
로그 조회 실패? → "로그는 못 봤어요" 표시하고 나머지 진단 계속
Slack 장애?    → 이메일은 정상 발송
플레이북 없음? → "수동으로 확인해주세요" 알림
```

---

## Part 5: 확장 방법

### 새 플레이북 추가 (예: ECS 태스크 부족 진단)

```python
# 1. lambda/runbook_engine/playbooks/ecs_task_low.py 생성
class EcsTaskLowPlaybook(BasePlaybook):
    @property
    def alarm_keys(self) -> list:
        return ["ecs_running_task_low"]

    def run(self, alarm_message: dict) -> DiagnosisResult:
        # describe-services → 태스크 수 확인
        # list-tasks → stopped 태스크 조회
        # → 왜 죽었는지? OOM? HealthCheck? Signal?
        ...

# 2. playbooks/__init__.py에 등록
from .ecs_task_low import EcsTaskLowPlaybook
_register(EcsTaskLowPlaybook)
```

**수정 범위: 파일 2개.** handler, notifier, Terraform 변경 불필요.

### 새 알림 채널 추가 (예: PagerDuty)

```python
# notifier.py에 메서드 추가
def _send_pagerduty(self, result: DiagnosisResult):
    if result.severity == "P1":
        # PagerDuty API로 incident 생성
        ...
```

### 새 알람 추가 (예: RDS 연결 수 과다)

```hcl
# alarms.auto.tfvars에 블록 추가
rds_connections_high = {
  namespace   = "AWS/RDS"
  metric_name = "DatabaseConnections"
  threshold   = 800
  severity    = "P2"
  ...
}
```

`terraform apply` 한 번으로 반영.

---

## Part 6: 운영 관점에서 배울 점

### IAM 최소 권한 — "할 수 있는 것"만 허용

| Lambda가 할 수 있는 것 | Lambda가 할 수 없는 것 |
|----------------------|---------------------|
| ✅ 서버 상태 읽기 | ❌ 서버 수정/삭제 |
| ✅ 로그 읽기 | ❌ 다른 사람 로그 읽기 |
| ✅ 결과를 지정된 토픽에 보내기 | ❌ 아무 토픽에나 보내기 |
| ✅ 자기 로그 쓰기 | ❌ 다른 로그 그룹에 쓰기 |

### DLQ + 동시성 제한 — "폭풍에도 안정적"

```
알람 100개 동시 발생!
  → Lambda 5개만 동시 실행 (제한)
  → 나머지 95개는 큐에서 대기
  → 처리 실패한 건 DLQ에 14일간 보관
  → 나중에 운영자가 확인 + 재처리 가능
```

### 로그 보관 — "나중에 볼 수 있게"

```
Lambda 실행 로그: 30일 보관 (CloudWatch Logs)
처리 실패 메시지: 14일 보관 (SQS DLQ)
```

---

## 실습 순서 권장

| 단계 | 뭘 하나 | 뭘 확인하나 |
|------|--------|-----------|
| 1 | `cd infra/test-env && terraform apply` | VPC, ALB, ECS 생성됐나 |
| 2 | `cd infra && terraform apply` | 알람, SNS, Lambda 생성됐나 |
| 3 | `terraform apply -var='health_check_matcher=201'` | 일부러 문제 유발 |
| 4 | AWS 콘솔 → CloudWatch → Alarms | ALARM 상태 확인 |
| 5 | AWS 콘솔 → Lambda → 로그 | 진단 로그 확인 |
| 6 | Slack | Block Kit 포맷 진단 결과 수신 확인 |
| 7 | `health_check_matcher=200` → `terraform destroy` | 복구 + 정리 |

---

## 비용 참고

| 리소스 | 대략적 비용 | 비유 |
|--------|------------|------|
| ALB (테스트용) | ~$0.023/시간 | 커피 한 잔/2일 |
| Fargate SPOT | ~$0.005/시간 | 거의 무료 |
| CloudWatch Alarms | $0.10/알람/월 | 알람 6개 = $0.6/월 |
| Lambda, SNS, SQS | Free tier | 무료 |

**테스트 후 반드시 `terraform destroy`로 정리할 것.** ALB가 계속 돌면 하루 ~$0.55.

---

## Part 7: 실습 회고 — 삽질과 배운 것

### E2E 검증 결과

실제 AWS에 배포하고 전체 파이프라인을 검증 완료:

```
CloudWatch: UnHealthyHostCount == 2 >= 1 → ALARM
  → SNS: Lambda에 전달
    → Lambda: 진단 실행
      → describe-target-health: 2/2 unhealthy
      → describe-services: desired=1, running=1
      → verdict: ALL_TARGETS_UNHEALTHY (P1)
    → Slack: 🔴 P1 진단 리포트 수신 ✅
```

Slack에서 받은 실제 메시지:
```
P1 Alert - Runbook Diagnosis
🔴 msp-monitoring-dev-alb_unhealthy_host

Verdict: ALL_TARGETS_UNHEALTHY
Severity: P1
Summary: All 2 targets are unhealthy.

Details:
• unhealthy_count: 2
• total_count: 2
• reasons: ['Target.DeregistrationInProgress', 'Target.ResponseCodeMismatch']
• ecs_running: 1
• ecs_desired: 1

👉 Recommended Action:
Escalate to MSP L2 and customer app team immediately.
```

---

### 삽질 기록

| 문제 | 원인 | 해결 |
|------|------|------|
| ECS 알람이 계속 경보 상태 | CloudWatch namespace 불일치. Container Insights를 켜면 메트릭이 `AWS/ECS`가 아니라 `ECS/ContainerInsights`로 들어감 | `alarms.auto.tfvars`의 ECS 알람 namespace를 `ECS/ContainerInsights`로 수정 |
| Lambda `TargetGroupNotFound` 에러 | `terraform.tfvars`의 `target_group_arn`이 이전 배포에서 생성된 ARN을 가리킴. 새로 배포하면 ARN suffix가 달라짐 | AWS 콘솔에서 새 Target Group ARN 확인 후 `terraform.tfvars` + `alarms.auto.tfvars` 업데이트 |
| test-env 없이 infra 먼저 배포 | 배포 순서 미숙지. 알람의 dimensions가 가리키는 리소스(ALB, ECS)가 아직 존재하지 않음 | `infra/test-env` 먼저 → `infra` 나중에 배포 |
| `.auto.tfvars`를 자동 생성으로 오해 | Terraform의 "auto"는 "자동 로드"의 의미이지 "자동 생성"이 아님 | 사람이 직접 작성하는 파일. Terraform이 apply 시 자동으로 읽어감 |

---

### 핵심 교훈

1. **배포 순서가 중요하다** — 대상 인프라(test-env) 먼저, 모니터링(infra) 나중에
2. **namespace를 정확히 확인해라** — Container Insights 활성화 여부에 따라 메트릭 위치가 달라짐
3. **ARN은 재배포하면 바뀐다** — 환경을 새로 만들면 관련 설정도 업데이트 필요
4. **`.auto.tfvars` = 자동 로드, 수동 작성** — 이름에 속지 말 것

---

### 코드 중요도 정리

```
핵심 (이해 필수):
  handler.py         — 이벤트 받고 필터링하고 플레이북 연결
  alb_target_5xx.py  — 실제 AWS API 호출 + 의사결정 트리

구조 (확장할 때 필요):
  __init__.py        — 전화번호부 (알람 키 → 플레이북 매핑)
  base.py            — 진단서 양식 (모든 플레이북이 따르는 계약)

부속 (교체 가능):
  notifier.py        — 발송 수단 (Slack, Email). 다른 걸로 바꿔도 진단에 영향 없음
  utils.py           — 알람 이름에서 키 추출. 단순 문자열 처리
```
