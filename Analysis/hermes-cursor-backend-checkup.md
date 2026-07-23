# Cursor를 Hermes 백엔드로 — 점검 (2026-07-23)

## 결론

**현재 환경에서 Cursor 추론 백엔드 경로는 동작 중.**  
사이드카 `/health` OK, `/v1/models` OK, `/v1/chat/completions` HTTP 200.  
Hermes 프로필 `provider: cursor`, `base_url: http://127.0.0.1:2389/v1`.

## 아키텍처 (기억용)

```
Hermes AIAgent  →  hermes-cursor-proxy (:2389/v1)  →  cursor-sdk 또는 agent CLI (ask)
```

- in-tree provider 없음 (정책 #16282). 구현: `d:\GitHub\AI\hermes-cursor-provider`
- Cursor = 텍스트 LLM. 도구는 Hermes 소유 (`<tool_call>` 에뮬레이션)

## 라이브 점검 결과

| 항목 | 상태 |
|------|------|
| `agent` CLI (`%LOCALAPPDATA%\cursor-agent\agent.cmd`) | 있음 |
| 플러그인 `%LOCALAPPDATA%\hermes\plugins\model-providers\cursor\` | 설치됨 (`__init__.py`, `plugin.yaml`) |
| 외부 레포 `hermes-cursor-provider` | 있음 |
| 사이드카 `:2389/health` | `ok`, `has_cursor_api_key`, `has_agent_cli`, `sdk_importable` 모두 true |
| `/v1/models` | `composer-2.5`, `auto` |
| 채팅 프로브 POST `/v1/chat/completions` | HTTP 200 (~30s) |
| Hermes `.env` `CURSOR_API_KEY` / `HERMES_CURSOR_BASE_URL` | 둘 다 설정됨 |
| `config.yaml` | `provider: cursor`, `default: cursor-grok-4.5-high-fast`, base_url 2389 |

## 사용 방법 (정상 운영)

1. 사이드카 기동 (새 터미널이면 PATH·키 포함):

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
# CURSOR_API_KEY는 Hermes .env 또는 프로세스 env
cd d:\GitHub\AI\hermes-cursor-provider
python -m hermes_cursor_proxy
```

2. Hermes에서 모델 선택: `hermes model` → **Cursor Agent**, 또는

```yaml
model:
  provider: cursor
  default: composer-2.5   # 또는 auto
  base_url: http://127.0.0.1:2389/v1
```

3. 슬래시: `/model cursor:composer-2.5`

## 주의점

1. **IDE `cursor.cmd` ≠ Agent CLI** — PATH의 Electron 런처로는 503 난다. `agent` 필요.
2. **키는 사이드카 프로세스에** — Hermes `.env`만으로는 proxy가 못 읽는다 (이미 기동된 proxy는 OK).
3. **기본 모델 불일치 가능** — 사이드카가 광고하는 id는 `composer-2.5` / `auto`인데, 현재 Hermes default는 `cursor-grok-4.5-high-fast`. 통과는 될 수 있으나, 명시적으로 `composer-2.5`로 맞추는 편이 안전.
4. **툴 콜은 텍스트 파싱** — 품질 들쭉날쭉하면 다른 provider가 나을 수 있음.
5. Gateway/cron은 사이드카 상시 가동 필요.

## 관련 문서

- `Analysis/hermes-cursor-provider.md` — 플러그인 개요
- `Analysis/hermes-cursor-503-fix.md` — 과거 503 원인/조치
- `Analysis/cursor-ide-integration-surfaces.md` — IDE MCP/ACP (추론 백엔드와 별개)
- 외부 README: `d:\GitHub\AI\hermes-cursor-provider\README.md`
