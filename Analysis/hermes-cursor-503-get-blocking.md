# Cursor 백엔드 503 수정 — os.get_blocking / CLI (2026-07-23)

## 증상

```
HTTP 503: Cursor backend unavailable.
cursor-sdk prompt failed: module 'os' has no attribute 'get_blocking'
| Cursor CLI not found: C:\Users\PM\AppData\Local\cursor-agent\agent.CMD
```

Provider: `cursor` / Model: `cursor-grok-4.5-high-fast` / Endpoint: `http://127.0.0.1:2389/v1`

## 원인

1. **`cursor-sdk` Windows 비호환** — `_bridge.py`가 POSIX 전용 `os.get_blocking` / `os.set_blocking`을 호출. Windows Python 3.11에는 속성 없음 → SDK 경로 즉시 실패.
2. **CLI 폴백 실패** — 구버전/중복 사이드카가 `.CMD`를 CreateProcess로 직접 실행하려다 `FileNotFoundError`. (파일은 `agent.cmd`로 존재함; `cmd.exe /c` 필요)
3. **(중간 실수)** 모델 id에서 `cursor-`를 벗겨 `grok-4.5-high-fast`로 보내면 Cursor CLI가 거부. 카탈로그 id는 `cursor-grok-4.5-high-fast` 그대로여야 함.

## 조치 (`hermes-cursor-provider`)

파일: `hermes_cursor_proxy/cursor_backend.py`

- Windows에서 SDK 런타임 사용 불가 시 **CLI 우선** (`sdk_runtime_usable=false`)
- CLI: `ComSpec /d /c`로 `.cmd` 실행, `%LOCALAPPDATA%\cursor-agent\agent.cmd` 명시 탐색
- 모델 id는 Cursor 카탈로그 이름 **passthrough**
- `/health`에 `sdk_runtime_usable`, `agent_cli` 추가

사이드카 재기동 후:

- `POST /v1/chat/completions` model=`cursor-grok-4.5-high-fast` → **HTTP 200**

## 후속 (같은 날) — WinError 206 / argv0=cmd.exe

증상:

```
Cursor CLI not found: ...\agent.cmd (argv0='C:\\WINDOWS\\system32\\cmd.exe')
```

실제 원인: Hermes 도구 스키마가 포함된 긴 프롬프트를 argv로 넘기면 Windows CreateProcess 한도(~32KB) 초과 → `FileNotFoundError [WinError 206]`. cmd.exe 부재가 아님.

수정: 프롬프트를 **stdin**으로 전달 (`agent -p`는 prompt 인자 없을 때 stdin 사용). 45KB body 프로브 → HTTP 200.

## 사용자 측

Hermes 채팅 재시도하면 됨. 사이드카가 죽었으면:

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
# CURSOR_API_KEY 로드 후
cd d:\GitHub\AI\hermes-cursor-provider
python -m hermes_cursor_proxy
```
