# Hermes Cursor 사이드카 ask/agent 모드 스위치

날짜: 2026-07-24

## 요약

`hermes-cursor-provider`에 `HERMES_CURSOR_MODE=ask|agent|plan` 추가.
기본은 **agent** (CLI `--mode` 생략). `ask`로 바꾸면 Hermes가 도구를 단독 소유.

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
| agent (기본) | `agent -p` (`--mode` 생략) | 가능하면 SDK local, 아니면 CLI |
| ask | `agent -p --mode=ask` | 사용 안 함 (ask 플래그 없음) |
| plan | `agent -p --mode=plan` | CLI |

## 주의

- agent면 Cursor가 파일/셸을 직접 씀 → Hermes 도구와 **이중 에이전트** 가능
- 긴 작업/PR은 Cloud Agent 위임이 더 적합
- `$HERMES_HOME/cursor_mode` 파일로 바꾸면 사이드카 재시작 불필요 (요청마다 읽음)
- env만 바꾼 경우 사이드카 재시작 필요

## 변경 파일 (hermes-cursor-provider)

- `hermes_cursor_proxy/cursor_backend.py` — `resolve_cursor_mode`, CLI flag, health
- `tests/test_backend.py` — mode 단위 테스트
- `README.md`, `start_hermes_cursor_proxy.bat`, `scripts/start-sidecar.ps1`
