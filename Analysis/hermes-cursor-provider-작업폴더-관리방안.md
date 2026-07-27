# hermes-cursor-provider를 hermes-agent 작업 폴더에서 관리하는 방안

- **일시**: 2026-07-27
- **문제**: provider가 형제 경로(`..\hermes-cursor-provider`)에 있어 Cursor 워크스페이스·검색·실행이 분리됨
- **제약**: upstream 정책(#16282 / AGENTS.md) — third-party product를 `plugins/` in-tree에 넣지 않음

---

## 현재 구조 (왜 불편한가)

```
d:\GitHub\AI\
  hermes-agent\          ← Cursor 워크스페이스 (이 폴더만 열림)
    start_*.bat          → PROXY_ROOT = ..\hermes-cursor-provider
  hermes-cursor-provider\  ← 별도 git remote (artzy/...), Cursor 밖
```

- **런타임 결합은 약함**: HTTP `:2389` + `$HERMES_HOME/plugins/...` 복사본
- **개발 결합은 강함**: bat·설치 스크립트·디버그가 형제 경로를 가정
- 코어 Python은 provider를 import하지 않음 → “안으로 넣는” 문제는 주로 **워크스페이스/경로/git 관리**

---

## 옵션 비교

| # | 방안 | 작업 폴더 안 노출 | upstream 정책 | git 복잡도 | 추천 |
|---|------|------------------|---------------|------------|------|
| A | Cursor multi-root workspace | IDE만 (디스크는 형제 유지) | 안전 | 없음 | 즉시 |
| B | 폴더 junction/symlink | 경로상 안으로 보임 | 안전 | 낮음 | Windows 로컬 |
| C | git submodule (`external/…`) | 진짜로 안 | fork에만 두면 안전* | 중 | **개발 추천** |
| D | nested clone + agent `.gitignore` | 진짜로 안 | 안전 | 낮음 | 단순 로컬 |
| E | vendor로 소스 흡수(모노레포) | 완전 통합 | upstream PR 불가 | 높음 | 비추천 |
| F | `$HERMES_HOME` 설치본만 관리 | 아님 | 안전 | 없음 | 개발에 부적합 |

\* `plugins/model-providers/cursor/`가 아니라 `external/`·`vendor/`·`third_party/` 등 **코어 플러그인 트리 밖**이면 정책 취지(코어 유지보수 부담)와 충돌이 적다. upstream으로 submodule을 올릴지는 별도 결정.

---

## A. Cursor multi-root workspace (가장 빠르고 안전)

디스크 위치는 그대로 두고, Cursor가 두 루트를 동시에 연다.

```json
// hermes-agent-with-cursor.code-workspace
{
  "folders": [
    { "path": ".", "name": "hermes-agent" },
    { "path": "../hermes-cursor-provider", "name": "hermes-cursor-provider" }
  ],
  "settings": {}
}
```

- **장점**: git/경로/정책 변경 없음, 검색·탭·터미널 cwd 전환 가능  
- **단점**: “폴더 안에 있다”는 감각은 약함, 다른 도구(탐색기 단독 오픈)는 여전히 형제

---

## B. Windows junction / symlink

```powershell
# hermes-agent 안에서 형제처럼 보이게
cmd /c mklink /J "d:\GitHub\AI\hermes-agent\hermes-cursor-provider" "d:\GitHub\AI\hermes-cursor-provider"
```

- bat의 `PROXY_ROOT=%AGENT_ROOT%\hermes-cursor-provider`로 바꾸면 형제 가정 제거
- junction 경로는 `.gitignore`에 넣고 **원격에 올리지 않음** (로컬 편의만)
- **주의**: git이 symlink/junction을 어떻게 다루는지(clone한 동료 PC) — 로컬 전용으로 한정할 것

---

## C. git submodule under `external/` (작업 폴더 내 관리의 정석)

```
hermes-agent/
  external/
    hermes-cursor-provider/   ← submodule → artzy/hermes-cursor-provider
  start_hermes_cursor_proxy.bat  → PROXY_ROOT=%AGENT_ROOT%\external\hermes-cursor-provider
```

작업 순서(요지):

1. `git submodule add https://github.com/artzy/hermes-cursor-provider.git external/hermes-cursor-provider`
2. agent bat / Analysis 문서의 `PROXY_ROOT`를 `external\...`로 수정
3. clone 시 `git clone --recurse-submodules` 또는 `git submodule update --init`

- **장점**: 한 워크스페이스에서 커밋·브랜치·PR을 각각 관리, 버전 핀(커밋 SHA) 가능  
- **단점**: submodule 워크플로 학습 비용; upstream(Nous)에 이 변경을 올리면 리뷰 논쟁 가능 → **origin(artzy) fork에만 유지**하고 upstream merge 시 빼는 전략이 현실적  
- **하지 말 것**: `plugins/model-providers/cursor/`로 submodule 배치 (정책 정면 충돌)

---

## D. nested clone + `.gitignore` (submodule 없이)

```
hermes-agent/
  external/hermes-cursor-provider/   ← 별도 .git, agent .gitignore에 추가
```

```gitignore
# .gitignore (hermes-agent)
/external/hermes-cursor-provider/
```

```powershell
mkdir external -Force
git clone https://github.com/artzy/hermes-cursor-provider.git external/hermes-cursor-provider
```

- **장점**: submodule보다 단순, Cursor로 agent만 열어도 provider 편집 가능  
- **단점**: 버전 핀/팀 공유가 약함(각자 clone), agent 커밋에 provider가 안 묶임

---

## E. 모노레포로 소스 흡수 — 비추천

provider 소스를 agent 트리에 복사해 한 remote로 관리.

- artzy fork 전용이면 기술적으로 가능하나, upstream sync마다 충돌·정책 위반 리스크
- `plugins/` 아래 배치하면 AGENTS.md 명시적 close 사유와 맞닿음
- 권장하지 않음

---

## F. `$HERMES_HOME`만 관리 — 개발용으로는 부족

이미 설치된 위치:

- `%LOCALAPPDATA%\hermes\plugins\model-providers\cursor\`
- `%LOCALAPPDATA%\hermes\plugins\cursor\`

런타임에는 여기가 진실이지만, 사이드카 소스·테스트·README는 리포에 있음 → **개발 워크스페이스 문제 해결 안 됨**.

---

## 추천 조합 (이 환경 기준)

로컬 목표가 “Cursor에서 한 작업 공간으로 다루기”라면:

1. **당장**: A (`.code-workspace` multi-root) — 리스크 0  
2. **폴더 트리까지 맞추려면**: **C 또는 D**로 `external/hermes-cursor-provider`에 두고  
   - `start_hermes_cursor_proxy.bat` / `restart_*.bat`의 `PROXY_ROOT`를 그 경로로 변경  
   - artzy fork에만 반영, Nous upstream에는 올리지 않거나 submodule 커밋을 제외  
3. **절대**: 코어 `plugins/model-providers/`에 Cursor를 넣지 않기

```
[선택] Cursor .code-workspace ──┐
                                ├─► 한 화면에서 agent + provider
[선택] external/ + bat PROXY_ROOT┘
         │
         ▼
   $HERMES_HOME/plugins/... (install-hermes-plugin.ps1)  ← 런타임
         │
         ▼
   hermes_cursor_proxy :2389  ← 사이드카
```

---

## 적용 시 최소 변경 목록

| 파일/위치 | 변경 |
|-----------|------|
| `start_hermes_cursor_proxy.bat` | `PROXY_ROOT` → `external\hermes-cursor-provider` (또는 junction 이름) |
| `restart_hermes_cursor_proxy.bat` | 동일 |
| `.gitignore` | D일 때 `external/hermes-cursor-provider/` |
| `.gitmodules` | C일 때 추가 |
| `*.code-workspace` | A일 때 추가 (커밋 여부는 선택) |
| provider README / Analysis | 경로 표기 갱신 |

코어 `run_agent.py` / `plugins/model-providers/` 변경은 **불필요**.

---

## 결정 가이드

| 원하는 것 | 고를 옵션 |
|-----------|-----------|
| 오늘 당장 IDE에서 같이 보고 싶다 | **A** |
| 탐색기에서 agent 폴더 아래에 두고 싶다 (git 단순) | **D** |
| agent 커밋에 provider 버전을 고정하고 싶다 | **C** |
| Windows에서만 빠르게 링크 | **B** (+ bat 수정) |
| upstream PR까지 한 레포로 | 하지 말 것 (E 금지) |
