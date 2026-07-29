# upstream 자동 검사·머지 — 참조 기록

작성·갱신: 2026-07-29  
대상: `artzy/hermes-agent` (fork of `NousResearch/hermes-agent`)

이 문서는 **특정 시간에 upstream을 검사하고, 충돌이 없으면 자동 머지**하는
구성을 다음에 다시 쓸 수 있도록 정리한 것이다.

---

## 한눈에 보기

| 항목 | 값 |
|------|-----|
| 워크플로 파일 | `.github/workflows/upstream-sync.yml` |
| 스케줄 | cron `0 21 * * *` → **매일 KST 06:00** (UTC 21:00) |
| 수동 실행 | Actions → Upstream sync → Run workflow, 또는 아래 `gh` 명령 |
| upstream | `https://github.com/NousResearch/hermes-agent.git` 의 `main` |
| 대상 브랜치 | fork의 `main` |
| Secret | `UPSTREAM_SYNC_TOKEN` (classic PAT: `repo` + `workflow`) |
| 충돌 시 | 머지하지 않음 → fork에 `upstream-sync` 라벨 이슈로 보고 |
| 성공 시 | merge 커밋 `[skip ci]` + `origin/main` push |
| 브랜치 보호 | Ruleset `main-no-delete` (ID `19936374`) — **삭제만 차단** |
| 검증 성공 실행 | https://github.com/artzy/hermes-agent/actions/runs/30423281043 |

로컬 클론은 자동으로 따라오지 않는다. 작업 전에:

```powershell
git pull origin main
```

---

## 동작 흐름

```text
schedule / workflow_dispatch
        │
        ▼
UPSTREAM_SYNC_TOKEN 존재 확인
        │
        ▼
checkout main (PAT 사용, fetch-depth: 0)
        │
        ▼
upstream/main fetch → behind 커밋 수
        │
   behind == 0 ──► 종료 (할 일 없음)
        │
        ▼
git merge-tree 로 충돌 사전 검사
        │
   충돌 있음 ──► 머지 안 함 → fork 이슈 보고 → 종료
        │
        ▼
git merge + push (커밋 메시지에 [skip ci])
        │
        ▼
성공 종료 (이슈 보고 스텝은 스킵)
```

설계 핵심: **충돌이 난 채로 저장소가 방치되는 상황을 만들지 않는다.**
`merge-tree`로 미리 보고, 충돌이면 push도 시도하지 않는다.

---

## 자주 쓰는 명령

```powershell
# 수동으로 지금 동기화
gh workflow run upstream-sync.yml --repo artzy/hermes-agent

# 최근 실행 확인 / 실시간 감시
gh run list --repo artzy/hermes-agent --workflow upstream-sync.yml --limit 5
gh run watch --repo artzy/hermes-agent

# secret·보호 규칙 확인
gh secret list --repo artzy/hermes-agent
gh api repos/artzy/hermes-agent/rules/branches/main

# 로컬에서 충돌만 미리 보기 (워킹트리 불변)
git fetch upstream
git merge-tree --write-tree --name-only main upstream/main
# → 트리 OID 한 줄만 나오면 충돌 없음
```

### 스케줄 변경

`.github/workflows/upstream-sync.yml`의 `cron`을 고친다. **단위는 UTC**다.

| 원하는 시각 (KST) | cron |
|-------------------|------|
| 매일 06:00 | `0 21 * * *` (현재) |
| 매일 09:00 | `0 0 * * *` |
| 매일 02:00 | `0 17 * * *` |
| 평일 06:00만 | `0 21 * * 1-5` |

Actions cron은 혼잡 시 수십 분 밀릴 수 있다. 정각 보장은 없다.

---

## 구성 요소 상세

### 1) GitHub Actions 워크플로

파일: `.github/workflows/upstream-sync.yml`

- `on.schedule` + `on.workflow_dispatch`
- `permissions`: `contents: write`, `issues: write`
- `concurrency.group: upstream-sync` (동시에 두 번 돌지 않음)
- checkout 토큰: `secrets.UPSTREAM_SYNC_TOKEN` (`persist-credentials: true`)
- 머지 메시지: `Merge remote-tracking branch 'upstream/main' [skip ci]`
  - PAT로 push하면 다른 워크플로가 깨어날 수 있어 CI 폭주 방지용
- 실패 보고: 모든 `gh` 호출에 `--repo "$GITHUB_REPOSITORY"` 명시
  - fork에서 `gh`가 부모(`NousResearch/...`)를 기본으로 잡는 문제 방지
- `actions/checkout` 핀: `de0fac2e...` (v6.0.2), 저장소 다른 워크플로와 동일

관련 커밋:

- `34ce60679` — 워크플로 최초 추가
- `b3b8cf7b5` — PAT push + fork 이슈 보고 수정
- `53d4a6fb9` — PAT 적용 후 첫 자동(수동 트리거) 머지 성공 (`[skip ci]`)

### 2) Repository secret `UPSTREAM_SYNC_TOKEN`

**왜 필요한가**

기본 `GITHUB_TOKEN`은 `.github/workflows/*` 변경을 push하지 못한다.
upstream이 워크플로를 고친 날이면 머지까지는 되고 push에서 거부된다.

```text
refusing to allow a GitHub App to create or update workflow
`.github/workflows/...` without `workflows` permission
```

**등록 요약** (상세는 아래 § PAT 등록)

1. classic PAT 발급 — scopes: `repo` + `workflow`
2. fork Settings → Secrets and variables → Actions
3. Name: `UPSTREAM_SYNC_TOKEN`

등록 확인(값은 안 보임):

```powershell
gh secret list --repo artzy/hermes-agent
```

### 3) 브랜치 보호 (삭제만)

Ruleset `main-no-delete` / ID `19936374` / `deletion`만 active.

- force push·직접 push·merge 커밋은 허용 → rebase/amend 후 force push 가능
- 소유자도 `main` 삭제 불가 (`current_user_can_bypass: never`)
- 삭제해야 할 때: 룰셋 비활성 또는 삭제 후 진행

```powershell
gh api --method PUT repos/artzy/hermes-agent/rulesets/19936374 -f enforcement=disabled
gh api --method DELETE repos/artzy/hermes-agent/rulesets/19936374
```

### 4) Issues 활성화

fork는 Issues가 기본 비활성이다. 충돌 보고용으로 켜 두었다.

```powershell
gh api --method PATCH repos/artzy/hermes-agent -F has_issues=true
```

이슈 라벨: `upstream-sync` (실패 시). 이미 열린 이슈가 있으면 댓글만 추가.

---

## PAT / Secret 등록 절차 (재발급 시)

> 토큰(`ghp_...`)을 채팅·커밋·이슈에 붙이지 말 것.  
> `gh auth login`의 OAuth(`gho_...`)와는 별개다. CLI 토큰을 secret에 넣지 말 것.

### classic PAT 발급

1. GitHub → Settings → **Developer settings**
2. **Personal access tokens** → **Tokens (classic)** → Generate
3. Note: `artzy-hermes-agent-upstream-sync`
4. Expiration: `90 days` 권장
5. scopes: **`repo`**, **`workflow`**
6. Generate 후 `ghp_...` 즉시 복사

### Secret 등록 (브라우저)

```text
github.com/artzy/hermes-agent
  → Settings
  → Secrets and variables → Actions
  → New repository secret  (또는 기존 Update)
  → Name: UPSTREAM_SYNC_TOKEN
```

### Secret 등록 (gh CLI)

```powershell
gh secret set UPSTREAM_SYNC_TOKEN --repo artzy/hermes-agent
# 프롬프트에 ghp_... 붙여넣고 Enter
gh secret list --repo artzy/hermes-agent
```

만료 시: **같은 이름**으로 값만 갱신하면 워크플로 파일은 손대지 않아도 된다.

---

## 장애·함정 기록

| 증상 | 원인 | 대응 |
|------|------|------|
| push 거부: workflow permission | `GITHUB_TOKEN`에 workflow 파일 push 권한 없음 | `UPSTREAM_SYNC_TOKEN`(repo+workflow)으로 checkout/push |
| 이슈/라벨 API가 `NousResearch/...`로 감 (403) | fork에서 `gh` 기본 대상이 부모 | `--repo "$GITHUB_REPOSITORY"` + `GH_REPO` |
| 스케줄이 안 돔 | fork 스케줄 워크플로는 비활성일 수 있음 / 60일 무활동 시 꺼짐 | Actions 탭에서 Upstream sync가 Active인지 확인, 수동 실행으로 깨우기 |
| 로컬이 예전 코드 | 원격만 갱신됨 | `git pull origin main` |
| PAT push 후 CI 폭주 | PAT 커밋은 다른 워크플로를 트리거함 | 머지 메시지에 `[skip ci]` (이미 적용) |

첫 실패 실행(수정 전): https://github.com/artzy/hermes-agent/actions/runs/30421816493  
수정 후 성공: https://github.com/artzy/hermes-agent/actions/runs/30423281043

---

## 로컬 수동 머지 (워크플로와 동일 정책)

자동화가 막혔거나 즉시 따라잡고 싶을 때:

```powershell
git fetch upstream
git merge-tree --write-tree --name-only main upstream/main   # 충돌 사전 확인
git merge upstream/main --no-edit
git push origin main
```

- **merge 권장** (force push 불필요, 개인 fork에서 히스토리 분기 허용)
- rebase는 커밋을 하나씩 얹어 중간 충돌·force push가 필요해 fork 일상 동기화에는 비추

최초 대량 머지(2026-07-29): upstream 732 커밋 ahead, 내 커밋 8개, 충돌 0 → `aec2e19a8`.

---

## 체크리스트 (다른 PC / 몇 달 뒤)

- [ ] `gh workflow list --repo artzy/hermes-agent` 에서 **Upstream sync** 가 `active`
- [ ] `gh secret list` 에 `UPSTREAM_SYNC_TOKEN` 존재 (PAT 만료일 확인)
- [ ] Ruleset `main-no-delete` 가 active (삭제만)
- [ ] Issues 사용 가능 (`has_issues`)
- [ ] 필요 시 `gh workflow run upstream-sync.yml --repo artzy/hermes-agent` 로 스모크
- [ ] 로컬: `git pull origin main` 후 작업

---

## 관련 파일

- `.github/workflows/upstream-sync.yml` — 자동 검사·머지 본체
- `Analysis/upstream-자동동기화.md` — 이 문서
- fork remotes: `origin` = artzy, `upstream` = NousResearch
