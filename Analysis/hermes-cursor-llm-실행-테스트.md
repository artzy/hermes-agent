# Hermes × Cursor LLM 실행 테스트

- **일시**: 2026-07-26
- **목표**: Hermes oneshot을 Cursor (`composer-2.5`, ask)로 실행

---

## 결과 요약

| 단계 | 결과 |
|---|---|
| Cursor 사이드카 `:2389` 기동 | ✅ |
| `/v1/models` → `composer-2.5`, `auto` | ✅ |
| `hermes cursor mode ask` | ✅ |
| oneshot (`--provider cursor -m composer-2.5`) | ❌ → cp949 수정 후 ❌ 인증 |
| 직접 `agent -p --mode=ask` | ❌ Authentication required |

**차단 원인 (현재):** Cursor Agent CLI 인증이 깨져 있음.  
`agent whoami`는 “Login successful”을 찍지만 `agent -p` / `auth status`는 `Authentication required`를 반환.  
`%LOCALAPPDATA%\hermes\.env`는 **비어 있음** (`CURSOR_API_KEY` 없음).

---

## 수정한 것 (사이드카)

Windows 한국어 로케일에서 stdin 프롬프트의 em dash(`—`)가 **cp949**로 인코딩되다 실패:

```
'cp949' codec can't encode character '\u2014'
```

`hermes-cursor-provider`에 적용:

1. `hermes_cursor_proxy/cursor_backend.py` — `subprocess.run(..., encoding="utf-8", errors="replace")`
2. `hermes_cursor_proxy/prompt.py` — 안내 문구 em dash → ASCII `--`

이 수정 후 에러가 **401 인증**으로 바뀌어 인코딩 문제는 해소됨.

---

## 사용자가 해야 할 인증

PowerShell에서 하나 선택:

```powershell
# A) 브라우저 로그인
agent login

# B) API 키를 Hermes .env에
# https://cursor.com/dashboard/integrations 에서 키 발급 후:
notepad $env:LOCALAPPDATA\hermes\.env
# CURSOR_API_KEY=...
```

그다음:

```powershell
# 사이드카 (provider 쪽 bat 권장)
d:\Github\AI\hermes-cursor-provider\start_hermes_cursor_proxy.bat

# Hermes 원샷
cd d:\Github\AI\hermes-agent
$env:HERMES_HOME = "$env:LOCALAPPDATA\hermes"
.\.venv\Scripts\hermes.exe -z "Reply with exactly OK" --provider cursor -m composer-2.5 --safe-mode
```

또는 `hermes model`에서 **Cursor Agent** / `composer-2.5` 선택 후 `hermes` 대화형 실행.

---

## 재테스트 명령 (인증 후)

```powershell
curl http://127.0.0.1:2389/health
# has_cursor_api_key:true 또는 agent login 세션 유효 확인

d:\Github\AI\hermes-agent\.venv\Scripts\hermes.exe -z "Reply with exactly OK" `
  --provider cursor -m composer-2.5 --safe-mode
```
