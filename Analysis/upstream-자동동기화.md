# upstream 자동 동기화 구성

작성일: 2026-07-29
대상 저장소: `artzy/hermes-agent` (fork of `NousResearch/hermes-agent`)

## 배경

GitHub이 `main` 브랜치가 보호되지 않았다는 배너를 띄운 것을 계기로, 브랜치 보호 정책을
정하고 upstream을 따라잡은 뒤 이후 동기화를 자동화했다.

이 저장소는 개인 fork이고 upstream은 하루 수백 커밋이 들어올 만큼 빠르게 움직인다.
그래서 "보호를 얼마나 걸 것인가"와 "얼마나 자주 따라갈 것인가"가 서로 얽힌 문제였다.

## 1. 브랜치 보호 — 삭제만 차단

### 판단 근거

`main`의 reflog를 보니 최근 일주일 사이 `rebase`, `filter-branch`, `commit --amend`,
`reset`이 모두 있었다. 넷 다 히스토리를 다시 쓰는 작업이고 원격 반영에 force push가
필요하다. 따라서 force push를 막는 순간 기존 작업 흐름 전체가 막힌다.

한편 1인 fork에서 PR 필수나 승인 필수는 순수한 마찰이고, 관리자 예외를 두면 보호가
장식이 된다. 실제 사고 중 되돌리기 가장 곤란한 것은 브랜치 삭제이므로 그것만 막았다.

### 적용 내용

Ruleset `main-no-delete` (ID `19936374`), enforcement `active`, 대상
`refs/heads/main`, 규칙은 `deletion` 하나뿐이다. bypass actor를 두지 않아
소유자도 삭제할 수 없다(`current_user_can_bypass: never`).

```powershell
# 적용
gh api --method POST repos/artzy/hermes-agent/rulesets --input ruleset.json

# 확인 — deletion 하나만 나와야 한다
gh api repos/artzy/hermes-agent/rules/branches/main

# 해제가 필요할 때
gh api --method PUT repos/artzy/hermes-agent/rulesets/19936374 -f enforcement=disabled
gh api --method DELETE repos/artzy/hermes-agent/rulesets/19936374
```

force push, 직접 push, merge 커밋, 서명 없는 커밋은 모두 종전대로 허용된다.

## 2. upstream 수동 머지 (1회)

머지 시점에 upstream이 732 커밋 앞서 있었고 내 고유 커밋은 8개였다.

병합 전에 워킹트리를 건드리지 않고 충돌을 미리 계산했다.

```powershell
git fetch upstream
git merge-tree --write-tree --name-only main upstream/main
```

출력이 트리 OID 한 줄뿐이면 충돌이 없다는 뜻이다. 결과는 충돌 0건이었고,
미추적 파일(`.understand-anything/`, Analysis 문서)도 upstream에 같은 경로가 없어
머지를 막지 않았다.

머지 방식은 rebase가 아니라 merge를 택했다. rebase는 8개 커밋을 하나씩 얹으면서
중간 단계에서 충돌할 수 있고 force push가 필요한 반면, merge는 force push 없이
끝나고 개인 fork에서 히스토리가 갈라지는 것은 실질적 문제가 아니다.

```powershell
git merge upstream/main --no-edit
git push origin main
```

결과 커밋은 `aec2e19a8`. 머지 후 내 커스터마이징이 그대로인지 라인 수로 확인했다
(`cli.py` +81, `.env.example` +24, `hermes_cli/models.py` +4,
`agent/model_metadata.py` +3, `agent/models_dev.py` +1, `package.json`).
`hermes.bat`과 `plugins/model-providers/together/`도 트리에 유지됐고,
`providers.get_provider_profile('together')`가 정상 반환하는 것까지 확인했다.

## 3. 자동 동기화 워크플로

`.github/workflows/upstream-sync.yml` — 매일 UTC 21:00 (KST 06:00) 실행 +
`workflow_dispatch` 수동 실행.

### 설계 원칙

자동 머지에서 가장 위험한 것은 충돌이 난 채 저장소가 방치되는 상황이다.
그래서 **검사 후 조건부 머지** 구조를 강제했다.

1. upstream fetch → 뒤처진 커밋 수 계산. 0이면 아무것도 하지 않고 종료.
2. `git merge-tree --write-tree`로 충돌 사전 계산.
3. 충돌 없음 → 머지 + push.
4. 충돌 있음 → **머지를 시도하지 않고** 이슈로 보고.

이슈는 `upstream-sync` 라벨로 중복을 막는다. 이미 열린 이슈가 있으면 새로 만들지
않고 댓글만 단다. 그렇지 않으면 한 달이면 이슈가 30개 쌓인다.

### merge-tree 출력 형식

충돌 시 종료 코드 1이며 출력은 다음 구조다. 인공 충돌 저장소를 만들어 직접 확인했다.

```
<트리 OID>
a.txt
b.txt
                        <- 빈 줄
Auto-merging a.txt
CONFLICT (content): Merge conflict in a.txt
```

따라서 파일 목록은 2번째 줄부터 첫 빈 줄 직전까지다.

```bash
files=$(printf '%s\n' "$out" | awk 'NR > 1 { if ($0 == "") exit; print }')
```

`set -e` 아래에서도 `if out=$(...)` 형태면 종료 코드 1에 스크립트가 죽지 않는다.

### 함께 바꾼 저장소 설정

fork는 이슈 기능이 기본 비활성이다. 켜지 않으면 충돌 보고가 실패한다.

```powershell
gh api --method PATCH repos/artzy/hermes-agent -F has_issues=true
```

### 권한

저장소의 기본 워크플로 토큰 권한은 `read`지만, 워크플로 파일의 `permissions:` 블록으로
`contents: write` / `issues: write`를 부여할 수 있다. write가 read로 강등되는 것은
fork에서 온 `pull_request` 이벤트에 한정되며 `schedule` / `workflow_dispatch`는
해당하지 않는다.

Actions 핀 정책(AGENTS.md)에 따라 `actions/checkout`은 저장소의 다른 워크플로와 같은
커밋 SHA(`de0fac2e...` = v6.0.2)로 고정했다.

## 알려진 제약

- fork에서는 스케줄 워크플로가 기본 비활성이다. push 후 활성 여부를 확인해야 하고,
  저장소에 60일간 활동이 없으면 GitHub이 자동으로 다시 끈다.
- Actions의 cron은 혼잡 시간대에 수십 분 밀릴 수 있다. "오전 6시 정각"은 보장되지 않는다.
- 원격 `main`만 갱신된다. 로컬 클론은 별도로 `git pull`해야 한다.
- `GITHUB_TOKEN`으로 push한 커밋은 다른 워크플로를 트리거하지 않는다. 따라서 매일 머지가
  upstream에서 상속받은 CI를 깨우지는 않는다(의도한 이점).
- 로컬 `.venv`에 pytest가 없어 머지 후 정식 테스트를 돌리지 못했다. 검증은 컴파일 +
  프로바이더 등록 스모크 체크 수준이었다.

## 앞으로의 수동 절차

로컬을 따라잡을 때는 다음을 쓴다.

```powershell
git fetch upstream
git merge-tree --write-tree --name-only main upstream/main   # 충돌 사전 확인
git merge upstream/main --no-edit
git push origin main
```
