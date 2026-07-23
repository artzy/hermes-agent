# Hermes Agent 프로젝트 분석

- **분석일**: 2026-07-22
- **버전**: 0.19.0 (`pyproject.toml`)
- **커밋**: `3e953ed815ffb1e35277a77eb3e764d39dcf36f7`
- **라이선스**: MIT (Nous Research)
- **언어**: Python 3.11–3.13 + TypeScript (TUI / Desktop / Dashboard)

---

## 1. 한 줄 요약

Hermes는 **동일 agent 코어**를 CLI · 메시징 게이트웨이 · Ink TUI · Electron 데스크톱에서 공유하는 자기개선형 AI 에이전트다. 핵심 원칙은 **프롬프트 캐싱 보존**과 **코어 최소 표면(허리 좁게, 가장자리 넓게)** 이다.

---

## 2. 제품 포지션

| 축 | 내용 |
|---|---|
| 학습 루프 | 스킬 생성/개선, 메모리, 세션 검색(FTS5), curator |
| 멀티 채널 | Telegram, Discord, Slack, WhatsApp, Signal 등 ~20+ 플랫폼 |
| 실행 환경 | local / Docker / SSH / Singularity / Modal / Daytona |
| 확장 | plugins + skills (+ MCP catalog) — 코어 도구 추가가 최후 수단 |
| 스케줄 | 내장 cron + 플랫폼 배달 |
| 위임 | `delegate_task` 서브에이전트 (leaf / orchestrator) |

---

## 3. 아키텍처 개요

```
사용자 표면
├── CLI (cli.py + hermes_cli/)          — prompt_toolkit / Rich
├── TUI (ui-tui + tui_gateway/)         — Ink ↔ JSON-RPC
├── Desktop (apps/desktop/)             — Electron + React + nanostores
├── Dashboard (web/ + hermes_cli/)      — 임베디드 TUI (PTY) + REST/WS
└── Gateway (gateway/)                  — 메시징 플랫폼 어댑터

공유 코어
├── run_agent.py          — AIAgent 대화 루프
├── model_tools.py        — 도구 디스커버리 / 디스패치
├── toolsets.py           — 플랫폼별 도구 번들
├── tools/                — registry.register() 자동 발견
├── agent/                — 메모리, 압축, 프로바이더, curator 등
└── hermes_state.py       — SQLite 세션 스토어

확장
├── plugins/              — memory / model-providers / platforms / …
├── skills/               — 기본 스킬
└── optional-skills/      — 옵트인 헤비 스킬
```

### 의존성 체인 (도구)

```
tools/registry.py
  ↑ tools/*.py  (import 시 register)
  ↑ model_tools.py
  ↑ run_agent.py / cli.py / batch_runner.py / environments
```

---

## 4. 규모 스냅샷 (파일 수, 대략)

| 영역 | 파일 수 | 비고 |
|---|---:|---|
| `tests/` | ~2,244 | 테스트 비중 매우 큼 |
| `apps/` | ~1,158 | desktop + shared + installer |
| `website/` | ~747 | Docusaurus 문서 |
| `skills/` + `optional-skills/` | ~1,052 | 스킬 자산 |
| `ui-tui/` | ~429 | Ink TUI |
| `plugins/` | ~318 | 확장 플러그인 |
| `hermes_cli/` | ~209 | CLI 서브커맨드 |
| `agent/` | ~157 | 에이전트 내부 |
| `tools/` | ~116 | 도구 구현 |
| `gateway/` | ~80 | 게이트웨이 런타임 |

### God-file (LOC 대략)

| 파일 | LOC | 역할 |
|---|---:|---|
| `gateway/run.py` | ~21k | 게이트웨이 오케스트레이터 |
| `cli.py` | ~14.5k | 인터랙티브 CLI |
| `hermes_cli/main.py` | ~13.7k | CLI 엔트리 / 서브커맨드 |
| `hermes_cli/config.py` | ~8.5k | 설정 스키마 / 마이그레이션 |
| `hermes_state.py` | ~7.2k | 세션 DB |
| `run_agent.py` | ~6k | AIAgent 코어 루프 |

문서(`AGENTS.md`)도 이 클러스터를 mixin/모듈로 쪼개는 리팩터를 **환영**한다.

---

## 5. 핵심 설계 원칙

1. **Per-conversation prompt caching**  
   대화 중 과거 컨텍스트/도구셋/시스템 프롬프트 변경 금지. 예외는 context compression뿐. 슬래시 커맨드의 상태 변경은 기본적으로 다음 세션 반영(`--now`로 즉시 무효화).

2. **Narrow waist / fat edges**  
   코어 모델 도구는 API마다 schema가 실려 비용이 든다. 새 기능은 가능하면 CLI+skill → service-gated tool → plugin → MCP → (최후) core tool 순으로.

3. **Profiles**  
   `HERMES_HOME`으로 완전 격리. 경로 하드코딩(`~/.hermes`) 금지 → `get_hermes_home()` / `display_hermes_home()`.

4. **Secrets vs settings**  
   `.env` = 시크릿만. 행동 설정은 `config.yaml`.

---

## 6. 주요 서브시스템

### 6.1 Agent Core

- `AIAgent.run_conversation()` — 동기 tool-calling 루프
- 메시지 역할 교대(strict alternation) 유지
- 컨텍스트 압축, 보조 LLM(`auxiliary`), credential pool, fallback model

### 6.2 Tools & Toolsets

- `tools/registry.py` — 스키마/핸들러/`check_fn`
- `toolsets.py` — `messaging`, `browser`, `terminal`, `delegation` 등
- 플랫폼별 `tools.<platform>.enabled/disabled` (`hermes tools`)

### 6.3 Gateway

- 단일 프로세스에서 다수 플랫폼 연결
- 코어 어댑터: `gateway/platforms/` (Signal, WhatsApp, Weixin, Yuanbao, webhook, …)
- 플러그인 어댑터: `plugins/platforms/` (Telegram, Discord, Slack, Matrix, Feishu, Teams, …)
- 실행 중 메시지 가드 2단(어댑터 큐 + runner 인터셉트) — `/stop`, `/approve` 등은 둘 다 우회 필요

### 6.4 Surfaces (UI)

| Surface | 기술 | 백엔드 |
|---|---|---|
| Classic CLI | Rich + prompt_toolkit | 직접 `AIAgent` |
| TUI | Ink (React) | `tui_gateway` JSON-RPC |
| Dashboard `/chat` | xterm.js + PTY | 임베디드 `hermes --tui` |
| Desktop | Electron + React | `hermes serve` + JSON-RPC |

### 6.5 Memory / Skills / Curator

- Memory providers: honcho, mem0, supermemory, byterover, hindsight, holographic, openviking, retaindb  
  (신규 인트리 memory provider는 정책상 닫힘 — 외부 플러그인으로)
- Skills: `skills/` 기본 활성, `optional-skills/` 명시 설치
- Curator: agent-created 스킬 수명주기(archive, pin, backup)

### 6.6 Cron / Kanban / Delegation

- **Cron**: duration / every-phrase / cron expr / ISO one-shot
- **Kanban**: SQLite 보드 + dispatcher + `kanban_*` toolset
- **Delegation**: 병렬 자식, depth leaf/orchestrator, 깊이·동시성 제한

### 6.7 Model Providers

`plugins/model-providers/`에 OpenRouter, Anthropic, Gemini, Bedrock, DeepSeek, Nous, Ollama Cloud 등 **30+** 프로파일. lazy discovery + last-writer-wins 오버라이드.

---

## 7. 설정·상태 위치

| 용도 | 경로 |
|---|---|
| 설정 | `~/.hermes/config.yaml` (또는 프로필 홈) |
| 시크릿 | `~/.hermes/.env` |
| 로그 | `~/.hermes/logs/` (`agent.log`, `errors.log`, `gateway.log`) |
| 세션 DB | `hermes_state` (프로필 스코프) |

로더 경로가 셋으로 갈라짐 — CLI `load_cli_config()`, 서브커맨드 `load_config()`, 게이트웨이 raw YAML. 새 키 추가 시 어느 로더에 닿는지 확인 필요.

---

## 8. 테스트·품질

- **반드시** `scripts/run_tests.sh` 사용 (CI parity: 자격증명 unset, TZ=UTC, xdist, file-retries)
- 테스트는 `~/.hermes`에 쓰지 않음 (`_isolate_hermes_home`)
- Change-detector 테스트 / 소스 텍스트 정규식 테스트 금지
- JS 아티팩트 검증은 vitest 쪽 (`tests-js`, workspace packages)

---

## 9. 기여·확장 시 체크리스트

1. 새 기능이 **코어 도구**여야 하는지 Footprint Ladder로 검증했는가?
2. 대화 중 캐시/역할 교대/시스템 프롬프트를 깨지 않는가?
3. `get_hermes_home()`을 쓰는가? (프로필 안전)
4. 비시크릿 설정이 `config.yaml` + `DEFAULT_CONFIG`에 있는가?
5. 게이트웨이/CLI 양쪽 로더를 봤는가?
6. 플러그인이 코어 파일을 패치하지 않는가?
7. 인트리 third-party SaaS 플러그인/신규 memory provider가 아닌가? (정책상 외부 레포)

---

## 10. 온보딩 추천 읽기 순서

1. `README.md` — 제품 개요·설치
2. `AGENTS.md` — 설계 의도·기여 루브릭 (필독)
3. `run_agent.py` — 대화 루프
4. `model_tools.py` + `tools/registry.py` — 도구 파이프라인
5. `gateway/run.py` + `gateway/platforms/base.py` — 메시징
6. `hermes_cli/commands.py` — 슬래시 커맨드 레지스트리
7. `ui-tui/` + `tui_gateway/` — TUI 프로세스 모델
8. `apps/desktop/AGENTS.md` — 데스크톱 전용 규칙

---

## 11. Knowledge Graph 분석 (후속)

전체 파일 수가 수천 개라 `/understand` 전체 스캔은 범위 제한이 필요하다.

- 설정: `.understand-anything/config.json` → `outputLanguage: ko`
- ignore 초안: `.understand-anything/.understandignore`
- 1차 패스 권장 exclude: `tests/`, `website/`, `locales/`, `contributors/`, `optional-skills/`, `skills/`, `.github/` 등

확인 후 Phase 1(SCAN)부터 지식 그래프를 생성할 수 있다.
