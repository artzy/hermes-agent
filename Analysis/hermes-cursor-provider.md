# Hermes ↔ Cursor Agent 백엔드 (standalone plugin)

날짜: 2026-07-23

## 요약

Cursor Agent를 Hermes 추론 백엔드로 쓰기 위한 연동은 **hermes-agent 코어에 넣지 않는다** (정책 #16282 / in-tree third-party product 금지). 산출물은 형제 디렉터리의 독립 플러그인 레포다.

## 외부 레포

- **경로:** `d:\GitHub\AI\hermes-cursor-provider`
- **구성:**
  - `model_provider/` — `ProviderProfile(name="cursor", aliases=cursor-agent/cursor-cli)`
  - `hermes_cursor_proxy/` — OpenAI-compat 사이드카 (`/v1/chat/completions`, `/v1/models`)
- **설치 위치 (프로필):** `%LOCALAPPDATA%\hermes\plugins\model-providers\cursor\`
- **기본 base_url:** `http://127.0.0.1:2389/v1`

## v1 시맨틱

- Cursor = ask/chat **텍스트** 백엔드 (Hermes가 도구 소유) — 기본
- `HERMES_CURSOR_MODE=ask|agent` (기본 `ask`). agent면 Cursor 자체 파일/셸 도구 활성
- 도구 스키마는 프롬프트에 직렬화, 응답의 `<tool_call>` → OpenAI `tool_calls` 파싱
- 인증: `CURSOR_API_KEY` 및/또는 `agent login`
- 런타임: ask는 CLI 고정(`--mode=ask`); agent는 SDK 가능 시 SDK, 아니면 CLI `--mode=agent`
- 상세: `Analysis/hermes-cursor-mode-switch.md`

## Hermes 코어 변경

없음.

## 사용 방법 (짧게)

1. `python -m hermes_cursor_proxy` 로 사이드카 기동
2. `hermes model` → **Cursor Agent** 선택
3. 자세한 설치/한계: 외부 레포 `README.md` 참고
