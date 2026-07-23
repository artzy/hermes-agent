# Hermes Agent — 테스트 좋은 예제

작성일: 2026-07-23  
출처: `website/docs/getting-started/quickstart.md`, `learning-path.md`, README

---

## 0. 시작 전 (한 번만)

```powershell
# 개발 체크아웃이라면 venv 활성화 후
hermes doctor          # 설정/의존성 진단
hermes setup           # 또는 hermes setup --portal (Nous 한 번에)
hermes model           # 프로바이더·모델 선택
hermes                 # 또는 hermes --tui
```

성공 기준: 배너에 모델이 보이고, 한 턴 이상 정상 응답.

---

## 1. 스모크 테스트 (가장 먼저)

채팅에서 그대로 붙여넣기:

| # | 프롬프트 | 검증 포인트 |
|---|----------|-------------|
| 1 | `Summarize this repo in 5 bullets and tell me what the main entrypoint is.` | 파일/터미널 도구 사용, `run_agent.py`/`cli.py` 언급 |
| 2 | `Check my current directory and tell me what looks like the main project file.` | `cwd` 인식, 프로젝트 파일 식별 |
| 3 | `Help me set up a clean GitHub PR workflow for this codebase.` | 다단계 조언 + 필요 시 도구 |

세션 재개:

```powershell
hermes --continue
# 또는 hermes -c
```

---

## 2. 핵심 기능별 예제

### 터미널

```
What's my disk usage? Show the top 5 largest directories.
```

Windows면:

```
현재 드라이브 여유 공간을 알려주고, 이 폴더에서 가장 큰 파일 5개를 찾아줘.
```

### 파일 읽기/편집

```
AGENTS.md를 읽고 Contribution Rubric의 "What we want"를 3줄로 요약해.
```

```
이 레포의 toolsets.py에서 _HERMES_CORE_TOOLS에 어떤 도구들이 있는지 나열해.
```

### 웹 검색 (키가 있을 때)

```
Hermes Agent Nous Research 최신 릴리스 노트를 찾아서 요약해.
```

### 슬래시 커맨드

| 명령 | 용도 |
|------|------|
| `/help` | 명령 목록 |
| `/tools` | 활성 도구 |
| `/model` | 모델 전환 |
| `/personality pirate` | 페르소나 스모크 |
| `/usage` | 토큰/사용량 |
| `/compress` | 컨텍스트 압축 |

### 위임(delegation)

```
README와 AGENTS.md를 나눠서 읽고, 각각 한 단락으로 요약한 뒤 합쳐줘. (delegate 사용 가능하면 병렬로)
```

### 크론 (CLI가 안정된 뒤)

```
내일 아침 9시에 이 레포의 git status를 요약해서 알려주는 cron job을 만들어줘.
```

또는:

```powershell
hermes cron list
hermes cron add --help
```

### 게이트웨이 (메시징)

```powershell
hermes gateway setup
hermes gateway start
```

텔레그램/디스코드 봇에: `안녕하세요. /help 보여줘.`

실전 가이드: [Daily Briefing Bot](https://hermes-agent.nousresearch.com/docs/guides/daily-briefing-bot), [Team Telegram Assistant](https://hermes-agent.nousresearch.com/docs/guides/team-telegram-assistant)

---

## 3. 개발자용 자동 테스트 (유닛/통합)

프로덕트 스모크와 별개로 CI 패리티 테스트:

```powershell
# 전체 (오래 걸림)
.\scripts\run_tests.sh

# 좁게
.\scripts\run_tests.sh tests/gateway/
.\scripts\run_tests.sh tests/agent/test_foo.py::test_x
```

Windows에서는 Git Bash/WSL에서 `scripts/run_tests.sh` 실행이 일반적.  
직접 `pytest` 호출은 권장하지 않음 (자격증명/환경 오염).

---

## 4. 추천 진행 순서

1. `hermes doctor` → 채팅 스모크 3개  
2. 터미널 + 파일 프롬프트  
3. `/tools`, `/model`, `hermes --continue`  
4. (선택) 웹/스킬/크론  
5. (선택) `hermes gateway`  
6. (개발) `scripts/run_tests.sh`로 관심 디렉터리만

규칙: **일반 채팅이 안 되면 게이트웨이·크론·라우팅을 붙이지 말 것.**

---

## 5. 참고 링크

- Quickstart: https://hermes-agent.nousresearch.com/docs/getting-started/quickstart  
- Learning Path: https://hermes-agent.nousresearch.com/docs/getting-started/learning-path  
- 영상 플레이리스트: Hermes Agent Tutorials & Use Cases (YouTube)
