# start_hermes_cursor_proxy.bat 환경 맞춤

- **일시**: 2026-07-27
- **대상**: `d:\GitHub\AI\hermes-cursor-provider\start_hermes_cursor_proxy.bat`
- **배경**: `hermes-agent`에 `.venv` 생성 + `pip install -e .` 완료. proxy 리포에는 `.venv` 없음.

---

## 변경 요지

| 항목 | 이전 | 이후 |
|------|------|------|
| Python | proxy `.venv` → 시스템 `python` | proxy `.venv` → **형제 `hermes-agent\.venv`** → 시스템 `python` |
| `.env` | `HERMES_HOME` → `~/.hermes` → sibling → `%LOCALAPPDATA%\hermes` | **형제 `hermes-agent\.env` 우선** → `HERMES_HOME` → … |
| `AGENT_ROOT` | 없음 | `PROXY_ROOT\..\hermes-agent` (절대경로 정규화) |

이 워크스페이스에서 `CURSOR_API_KEY`는 `hermes-agent\.env`에 있고, `%LOCALAPPDATA%\hermes\.env`는 없음.

## 기대 기동 로그

```
Starting hermes-cursor-proxy from:
  D:\GitHub\AI\hermes-cursor-provider
Python:
  D:\GitHub\AI\hermes-agent\.venv\Scripts\python.exe
Endpoint:
  http://127.0.0.1:2389/v1
```

## 검증

```powershell
cd D:\GitHub\AI\hermes-cursor-provider
& D:\GitHub\AI\hermes-agent\.venv\Scripts\python.exe -c "import hermes_cursor_proxy; print('ok')"
```

cwd가 proxy 루트이면 editable 설치 없이도 `-m hermes_cursor_proxy` import 가능.
