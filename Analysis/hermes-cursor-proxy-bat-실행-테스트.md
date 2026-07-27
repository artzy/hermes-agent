# start_hermes_cursor_proxy.bat 실행 테스트

- **일시**: 2026-07-27
- **대상**: `d:\GitHub\AI\hermes-agent\start_hermes_cursor_proxy.bat`
- **PROXY_ROOT**: `D:\GitHub\AI\hermes-cursor-provider`

---

## 결과 요약

| 단계 | 결과 |
|------|------|
| 기존 `:2389` 프로세스 종료 | ✅ |
| bat으로 사이드카 기동 | ✅ (`python -m hermes_cursor_proxy`) |
| `GET /health` | ✅ `ok=true`, `has_cursor_api_key=true` |
| `GET /v1/models` | ✅ `composer-2.5`, `auto`, `cursor-grok-4.5-high-fast` |
| `POST /v1/chat/completions` | ✅ content=`OK` (~28s) |

---

## 기동 로그 (bat)

```
Starting hermes-cursor-proxy from:
  D:\GitHub\AI\hermes-cursor-provider
Python:
  python
Endpoint:
  http://127.0.0.1:2389/v1
```

참고: proxy 리포에 `.venv`/`venv` 없음 → 시스템 `python` 사용.

## health 스냅샷

```json
{
  "ok": true,
  "has_cursor_api_key": true,
  "has_agent_cli": true,
  "sdk_importable": true,
  "sdk_runtime_usable": false,
  "agent_cli": "C:\\Users\\PM\\AppData\\Local\\cursor-agent\\agent.cmd",
  "cursor_mode": "agent",
  "cursor_mode_file_value": "agent"
}
```

`sdk_runtime_usable=false`이지만 Agent CLI 경로로 chat 완료됨.

## chat 요청

- model: `composer-2.5`
- prompt: `Reply with exactly OK and nothing else.`
- response: `OK`
