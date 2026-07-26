# Hermes Agent 실행 테스트

- **일시**: 2026-07-26
- **커밋**: `0a129a069d4c94efef6b99c799f8dd89b4c418ed`
- **버전**: 0.19.0 (2026.7.20)
- **환경**: Windows 10, Python 3.11.7, uv 0.7.2

---

## 요약

| 항목 | 결과 |
|---|---|
| `uv sync` / `.venv` 생성 | ✅ |
| `hermes --version` / `--help` | ✅ |
| `hermes doctor` | ✅ (exit 0; setup/.env 안내 남음) |
| `hermes doctor --fix` | ✅ 3건 자동 수정 |
| `hermes status` | ✅ |
| 코어 import (`AIAgent`, tools) | ✅ (도구 28개 로드) |
| 단위 테스트 (registry + commands) | ✅ **217 passed** |
| `hermes_constants` 테스트 | ⚠️ 109 passed / **2 failed** (Windows 기본 경로) |
| `scripts/run_tests.sh` (Git Bash) | ❌ Windows `.venv/Scripts` 미인식 (`bin/activate`만 탐지) |
| 원샷 LLM (`-z`) | ✅ Together AI → 응답 `OK` |

**결론**: 로컬 실행·CLI·코어 도구 로드·명시적 모델 원샷은 정상. 대화형 채팅을 쓰려면 `hermes setup`으로 `.env`/모델을 고정하는 것이 좋다.

---

## 수행 명령

```powershell
cd d:\Github\AI\hermes-agent
uv sync --python 3.11
.\.venv\Scripts\hermes.exe --version
.\.venv\Scripts\hermes.exe doctor
.\.venv\Scripts\hermes.exe doctor --fix
.\.venv\Scripts\hermes.exe status

# 단위 테스트 (Windows 네이티브)
uv pip install pytest pytest-xdist
.\.venv\Scripts\python.exe -m pytest tests/tools/test_registry.py tests/hermes_cli/test_commands.py -q -p no:xdist

# 원샷 (모델 미지정 시 Together 404 → 모델 명시 후 성공)
$env:HERMES_HOME = "$env:TEMP\hermes-smoke-test2"
.\.venv\Scripts\hermes.exe -z "Reply with exactly the two letters OK and nothing else." `
  -m "meta-llama/Llama-3.3-70B-Instruct-Turbo" --provider together --safe-mode
```

---

## doctor 하이라이트

- Python / venv / SSL / 필수 패키지: 정상
- Together AI 연결: 정상 (키는 기존 환경에 존재)
- `.env` 없음 → `hermes setup` 권장
- `config.yaml` 없음 (defaults 사용)
- 메시징 플랫폼·게이트웨이: 미구성 / stopped
- `state.db`: doctor --fix 전 “no such table: sessions” 경고 → fix로 일부 해소

---

## 발견된 Windows 이슈

1. **`scripts/run_tests.sh`**  
   venv 탐지가 `$VENV/bin/activate`만 봄 → Windows는 `Scripts/activate`라 Git Bash에서 “no virtualenv found”.

2. **`tests/test_hermes_constants.py` 2건**  
   네이티브 기본 홈이 `~/AppData/Local/hermes`인데, 테스트는 mocked home 아래 `.hermes`를 기대. Windows 플랫폼 경로와 fixture 불일치로 보임 (제품 실행에는 영향 없음).

3. **원샷 기본 모델**  
   Provider는 Together로 잡히나 모델이 비어 있으면 HTTP 404. `-m <model>` 지정 또는 `hermes model` / setup으로 기본 모델 설정 필요.

---

## 다음 권장 스텝 (사용자)

```powershell
.\.venv\Scripts\hermes.exe setup   # .env + 모델/키
.\.venv\Scripts\hermes.exe         # 인터랙티브 CLI
# 또는
.\.venv\Scripts\hermes.exe --tui
```
