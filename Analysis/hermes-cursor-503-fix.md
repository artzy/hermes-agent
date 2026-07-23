# Hermes Cursor 503 수정 기록

날짜: 2026-07-23

## 증상

```
HTTP 503: Cursor backend unavailable. cursor-sdk is not installed; falling through to CLI
| Cursor CLI not found: C:\Program Files\cursor\resources\app\bin\cursor.CMD
```

## 원인

1. **IDE `cursor.cmd` ≠ Cursor Agent CLI**  
   PATH의 `cursor.CMD`는 Electron 에디터 런처. `agent -p --mode=ask` 용 CLI가 아님.
2. **`agent` CLI 미설치** — `%LOCALAPPDATA%\cursor-agent`에 logs만 있고 바이너리 없음.
3. **`cursor-sdk` 미설치** — 사이드카 Python(3.11)에 패키지 없음.
4. **사이드카에 `CURSOR_API_KEY` 미전달** — Hermes `.env`에만 있고 proxy 프로세스 env에 없음.
5. **(후속)** CLI 설치 후 Workspace Trust 게이트 → `--trust` 필요.

## 조치

1. Cursor Agent CLI 설치: `irm 'https://cursor.com/install?win32=true' | iex`  
   → `agent` @ `%LOCALAPPDATA%\cursor-agent\agent.cmd` (2026.07.20)
2. 사이드카를 `CURSOR_API_KEY` + 갱신된 PATH로 재기동  
   → `/health`: `has_cursor_api_key=true`, `has_agent_cli=true`
3. `hermes-cursor-provider` CLI 호출에 `--trust` 추가, Windows `.cmd`는 `cmd.exe /c`로 실행

## 검증

`POST http://127.0.0.1:2389/v1/chat/completions` → HTTP 200

## 사용자 재시도

Hermes 채팅만 다시 실행하면 됨 (사이드카는 이미 기동됨).  
새 터미널에서 사이드카를 띄울 때는 PATH에 `agent`가 보이게 한 뒤:

```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
# Hermes .env에서 CURSOR_API_KEY 로드 후
cd d:\GitHub\AI\hermes-cursor-provider
python -m hermes_cursor_proxy
```
