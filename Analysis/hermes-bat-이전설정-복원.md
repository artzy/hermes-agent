# hermes.bat — 이전 Cursor 설정 복원

- **일시**: 2026-07-27
- **HERMES_HOME**: `C:\Users\PM\AppData\Local\hermes`
- **런처**: `D:\GitHub\AI\hermes-agent\hermes.bat` (`.venv\Scripts\hermes.exe`)

---

## 배경

`config.yaml`과 `plugins/`가 비어 있어 `status`에서 Model `(not set)` / `.env not found`처럼 보였음.  
이전 운영 값(Analysis·대화 기록 기준)으로 복원.

---

## 수행 작업

| 단계 | 내용 | 결과 |
|------|------|------|
| Cursor model-provider 설치 | `%LOCALAPPDATA%\hermes\plugins\model-providers\cursor\` | ✅ |
| Cursor CLI 플러그인 설치 | `%LOCALAPPDATA%\hermes\plugins\cursor\` | ✅ |
| `hermes plugins enable cursor` | entrypoint 플러그인 enabled | ✅ |
| `cursor_mode` | `agent` | ✅ |
| `hermes-cursor-provider` editable | agent `.venv`에 `pip install -e .` | ✅ |
| `ddgs` | agent `.venv`에 9.x 설치 | ✅ |
| config 복원 | 아래 YAML | ✅ |

### `config.yaml` (복원 핵심)

```yaml
model:
  provider: cursor
  default: cursor-grok-4.5-high-fast
  base_url: http://127.0.0.1:2389/v1
web:
  backend: ddgs
  search_backend: ddgs
  extract_backend: firecrawl
```

`.env`는 이미 존재 (`CURSOR_API_KEY`, `HERMES_CURSOR_BASE_URL`, Firecrawl 키).

---

## 검증

| 검사 | 결과 |
|------|------|
| `hermes.bat status` | Model=`cursor-grok-4.5-high-fast`, Provider=`Cursor Agent`, `.env` ✓ |
| sidecar `:2389/health` | `ok`, `has_cursor_api_key=true`, `cursor_mode=agent` |
| oneshot `-z "Reply with exactly OK…"` | 응답 `OK`, exit 0 (~33s) |

---

## 사용

```bat
D:\GitHub\AI\hermes-agent\hermes.bat
```

대화형 실행 전 사이드카가 떠 있어야 함 (`start_hermes_cursor_proxy.bat`).  
셸에 `HERMES_HOME`이 비어 있거나 `%LOCALAPPDATA%\hermes`를 가리키면 이 설정을 사용한다.
