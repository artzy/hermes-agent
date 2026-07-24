# 클라우드에서 Hermes가 Cursor를 더 강력하게 쓰는 방법

날짜: 2026-07-23

## 한 줄 결론

지금 구조(Cursor = ask 모드 텍스트 백엔드)로는 **클라우드 Cursor의 진짜 힘**(VM·레포 클론·에이전트 루프·PR 생성)을 거의 안 쓴다.  
강화 방향은 Cursor를 LLM으로 더 쥐어짜는 게 아니라, **Hermes가 오케스트레이터 / Cursor Cloud Agent가 실행기**가 되는 **위임(delegation) 경로**를 여는 것이다.

## 현재 상태 (이미 있는 것)

| 경로 | 역할 | 클라우드 파워 |
|------|------|---------------|
| `hermes-cursor-provider` 사이드카 | Cursor ask/chat → Hermes 추론 | 약함 (local + ask, 도구는 Hermes) |
| `hermes mcp serve` | Cursor → Hermes 메시징 브리지 | 무관 (채널만) |
| `hermes acp` | IDE용 Hermes 에이전트 | Cursor 공식 ACP 클라이언트 없음 |
| Cursor SDK Cloud (`cloud: { repos }`) | Cursor-hosted VM + PR | **강함 — 아직 Hermes에 연결 안 됨** |

정책: Cursor 전용 연동은 hermes-agent **in-tree 금지** (#16282). `hermes-cursor-provider` / `~/.hermes/plugins` standalone만.

## 왜 지금이 약한가

`cursor_backend.py` 설계 의도:

- `LocalAgentOptions(cwd=...)` 만 사용 (cloud 옵션 없음)
- CLI도 `--mode=ask`
- "Cursor own agentic file/shell tools" 의도적 비활성 → nested agent loop 방지

즉 Hermes의 도구/메모리/게이트웨이는 살리되, Cursor Cloud의 **코딩 에이전트 본체**는 끈 상태다.

## 권장 아키텍처 (역할 분리)

```text
사용자 (Telegram/CLI/Cron)
        │
        ▼
   Hermes (오케스트레이터)
   · 메모리 / 스킬 / 승인 / 멀티채널
   · 짧은 작업: terminal·file·delegate_task
        │
        │  큰 코딩 작업만
        ▼
   Cursor Cloud Agent (실행기)
   · repos clone on VM
   · 자체 도구 루프
   · auto_create_pr / resume(bc-...)
        │
        ▼
   결과 요약 → Hermes 세션으로 회수
```

원칙:

1. **일상 대화·도구 루프** → 지금처럼 Hermes 소유 (프롬프트 캐시·toolset 안정)
2. **장시간 레포 작업·PR** → Cursor Cloud에 한 방 위임
3. Cursor를 매 턴 chat completions로 쓰는 방식은 유지해도 되지만, "강력함"의 본체는 2번이다

## 구현 사다리 (Footprint Ladder에 맞춤)

### A. 즉시 (설정·운영, 코드 거의 없음)

1. `CURSOR_API_KEY`를 사이드카·게이트웨이 프로세스 양쪽에 확실히
2. 모델 id를 사이드카 카탈로그와 맞춤 (`composer-2.5` / `auto`)
3. 게이트웨이/cron용 사이드카 상시 기동
4. Cursor IDE에서는 `hermes mcp serve`로 메시징·승인만 연결

### B. 단기 — Skill + CLI (코어 도구 0)

`hermes cursor-cloud run|status|resume` 형태의 **standalone CLI + skill**:

- `cursor_sdk.Agent.create(..., cloud=CloudAgentOptions(repos=[...], auto_create_pr=True))`
- `Agent.resume("bc-...")` 로 cron/webhook 이어하기
- 결과는 요약 텍스트 + PR URL을 Hermes 세션/채널로 delivery
- 인증·repo 접근은 서비스 계정 키 권장

Hermes 설계와 가장 잘 맞음: 코어 tool schema 안 늘림.

### C. 중기 — Plugin tool (service-gated)

`check_fn`으로 `CURSOR_API_KEY` 있을 때만 노출:

- `cursor_cloud_delegate(goal, repo, branch?, auto_pr?)`
- `cursor_cloud_status(agent_id)` / `cursor_cloud_resume(...)`

주의: 매 API 콜 footprint. B가 충분하면 C는 선택.

### D. 중기 — 사이드카 이중 모드 (hermes-cursor-provider 확장)

| 모드 | 용도 |
|------|------|
| `ask` (현재) | Hermes가 도구 소유하는 일반 턴 |
| `cloud_agent` | 명시적 위임 엔드포인트 (`/v1/cursor/cloud/runs`) |

chat completions에 cloud를 몰래 넣지 말 것 — 턴마다 VM/비용/캐시 깨짐.

### E. 비권장 / 후순위

- Cursor를 Hermes 코어 model-provider로 in-tree 추가
- ask 모드에서 Cursor 도구를 켠 nested loop (이중 에이전트, 비용·승인 혼란)
- 새 코어 `cursor_*` 도구를 `_HERMES_CORE_TOOLS`에 상시 포함
- Cursor용 ACP를 공식인 척 문서화 (클라이언트 미지원)

## Cloud 위임 시 체크리스트

- 런타임 **명시**: `cloud=CloudAgentOptions(repos=[...])` (생략 시 조용히 local)
- `auto_create_pr` / `skip_reviewer_request` CI·봇용으로 설정
- `agent_id` / `run.id` 즉시 로그 → Hermes cron으로 `resume`
- MCP를 Cloud에 붙일 때: HTTP 권장, stdio env는 시크릿 취급
- resume 시 inline MCP는 다시 전달 필요
- startup 실패(`CursorAgentError`) vs run 실패(`status==error`) 분리
- 팀 서비스 계정 키 + 레포 권한 확인

## Hermes 쪽에서 같이 올려야 하는 것

Cursor Cloud만 켜도 Hermes가 약하면 체감이 안 난다.

1. **메모리 provider** — 위임 전후 맥락 유지
2. **skills** — "언제 cloud에 넘길지" 판단 가이드
3. **cron / kanban** — 긴 작업 상태 폴링·재개
4. **delegation** — 로컬 서브에이전트 vs Cursor Cloud 역할 분담을 스킬에 명시
5. **승인 UX** — PR/머지 전 gateway `/approve` 패턴

## 추천 실행 순서

1. 현 ask 사이드카는 **유지** (대화형 Hermes 루프용)
2. `hermes-cursor-provider`에 **cloud 위임 CLI/엔드포인트** 추가 (B 또는 D)
3. 스킬: "큰 리팩터·멀티파일·PR 필요 → cursor-cloud, 그 외 → Hermes tools"
4. Gateway cron으로 `bc-` 에이전트 resume/폴링
5. 체감 검증: 실제 repo에 PR 하나 자동 생성되는 E2E

## 관련 경로

- `d:\GitHub\AI\hermes-cursor-provider` — 현 provider/사이드카
- `Analysis/hermes-cursor-provider.md`
- `Analysis/hermes-cursor-backend-checkup.md`
- `Analysis/cursor-ide-integration-surfaces.md`
