# Hermes Cursor 사이드카 ask/agent 모드 스위치

날짜: 2026-07-24

## 요약

`hermes-cursor-provider`에 `HERMES_CURSOR_MODE=ask|agent` 추가.
기본은 기존과 동일하게 **ask**. agent로 바꾸면 CLI가 `--mode=agent`로 돈다.

## 사용법

Hermes `.env` 또는 사이드카 프로세스 env:

```env
HERMES_CURSOR_MODE=agent
```

PowerShell:

```powershell
$env:HERMES_CURSOR_MODE = "agent"
cd d:\GitHub\AI\hermes-cursor-provider
python -m hermes_cursor_proxy
# 또는
.\scripts\start-sidecar.ps1 -Mode agent
```

확인: `GET http://127.0.0.1:2389/health` → `"cursor_mode":"agent"`

## 동작

| 모드 | CLI | SDK |
|------|-----|-----|
| ask (기본) | `agent -p --mode=ask` | 사용 안 함 (ask 플래그 없음) |
| agent | `agent -p --mode=agent` | 가능하면 SDK local, 아니면 CLI |

## 주의

- agent면 Cursor가 파일/셸을 직접 씀 → Hermes 도구와 **이중 에이전트** 가능
- 긴 작업/PR은 Cloud Agent 위임이 더 적합
- 모드 변경 후 **사이드카 재시작** 필요

## 변경 파일 (hermes-cursor-provider)

- `hermes_cursor_proxy/cursor_backend.py` — `resolve_cursor_mode`, CLI flag, health
- `tests/test_backend.py` — mode 단위 테스트
- `README.md`, `start_hermes_cursor_proxy.bat`, `scripts/start-sidecar.ps1`
