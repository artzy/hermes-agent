# LLM 폴더용 hermes.bat

- **일시**: 2026-09-24
- **대상**: `D:\Github\AI\LLM\hermes.bat`
- **위임**: `D:\Github\AI\hermes-agent\hermes.bat`

## 동작

`D:\Github\AI\LLM\hermes.bat`는 이 폴더를 Hermes 작업 공간으로 잡고 기존 런처를 호출한다.

| 항목 | 값 |
|------|-----|
| primary cwd | `D:\Github\AI\LLM` (`%~dp0`) |
| 프로젝트 이름 | `LLM` |
| 프로젝트 slug | `llm` |
| 모델 | `qwen3.8-flash-next` (`--provider llm`) |
| API | `http://127.0.0.1:8080/v1` |
| 프록시 | `HERMES_SKIP_PROXY=1` (Cursor 사이드카는 띄우지 않음) |
| venv / 프로젝트 | `hermes-agent\hermes.bat`가 처리 |

`/health`가 ok가 아니면 `scripts\start-llama-server.ps1`를 새 창에서 켜고 최대 5분 기다린다. 브라우저는 열지 않는다.

기본 모델 `cursor-grok-4.5-high-fast`는 `%LOCALAPPDATA%\hermes\config.yaml`의 `model:`에 그대로 둔다. 이 런처만 `custom_providers`의 `llm` 항목(context_length 65536)을 쓴다. llama-server의 실제 창은 32768이다.

`HERMES_WORKDIRS`가 설정되면 `hermes.bat`의 기본 폴더(`HSUniv`, `hermes-agent`)보다 우선한다.

## hermes-agent 쪽 수정

`hermes.bat` 상단에서 `HERMES_PROJECT_NAME` / `HERMES_PROJECT_SLUG`를 무조건 `Local Workspace` / `local-workspace`로 덮어쓰던 줄을 제거했다. 호출자가 비워 두면 아래 `if not defined` 기본값이 그대로 적용된다. LLM 런처가 `local-workspace`의 primary를 바꾸지 않게 하기 위한 수정이다.

## 실행

```text
D:\Github\AI\LLM\hermes.bat
D:\Github\AI\LLM\hermes.bat --version
```
