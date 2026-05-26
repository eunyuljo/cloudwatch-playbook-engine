# AI Workflow for MSP Operations

## Purpose

Use Claude Code, Codex, Cursor, and MCP tools as separate roles in the MSP
documentation and operations workflow.

## Recommended Roles

| Tool | Role |
|---|---|
| Claude Code | Planning, architecture reasoning, operating model design |
| Codex | File creation, implementation, validation, review |
| Codex plugin in Claude Code | LLM-as-judge, adversarial review, rescue investigation |
| Cursor | Manual editing workspace and close code/document review |
| AWS Docs MCP | AWS official documentation lookup |

## Planning Flow

```text
Claude Code drafts the operating plan
-> Codex writes the guide files
-> Codex or Claude reviews as LLM-as-judge
-> AWS Docs MCP verifies AWS metric and service assumptions
-> Human operator approves operational policy
```

## Claude Code Prompt: Planning

```text
AWS MSP operating model을 설계해줘.
대상은 샘플 웹 애플리케이션이고 서비스는 CloudFront, WAF, ALB, ECS Fargate,
Aurora MySQL, Lambda, S3, CloudTrail, GuardDuty야.
아직 파일은 수정하지 말고 운영 범위, 모니터링 기준, severity, escalation,
playbook 작성 순서를 제안해줘.
```

## Codex Prompt: File Creation

```text
현재 폴더에 guide 디렉터리를 만들고 AWS MSP 운영 가이드를 단계별 Markdown으로 작성해줘.
포함할 내용:
- 운영 범위
- 모니터링 매트릭스
- severity/escalation
- ALB Target 5xx playbook
- playbook template
- Claude Code + Codex 활용 workflow
```

## Codex Plugin Commands in Claude Code

```text
/codex:review --background
/codex:adversarial-review --background focus on unsafe mitigation, missing escalation criteria, and ambiguous AWS assumptions
/codex:rescue investigate why the monitoring playbook is incomplete
/codex:status
/codex:result
```

## LLM-as-Judge Criteria

Use the judge role to check:

- Missing escalation criteria.
- Unsafe mitigation steps.
- Ambiguous AWS assumptions.
- Lack of customer/MSP ownership separation.
- Missing first-response evidence.
- Playbooks that do not produce actionable next steps.

Do not treat LLM review as final approval. Final operational approval should
come from a human owner and, where applicable, AWS documentation or production
runbook validation.
