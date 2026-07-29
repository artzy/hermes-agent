# Cursor에서 Hermes식 Self-Skill Loop 만들기

다른 프로젝트에서도 참조할 수 있도록, Hermes Agent의 스킬 자기생성 루프를 Cursor로 이식하는 방법을 정리한다.

## 목표

작업 중 생긴 시행착오·사용자 피드백을 수집해, Cursor Agent가 스스로 `SKILL.md`를 만들거나 갱신하게 한다.

## Hermes 참고 모델

Hermes는 네 층으로 학습한다.

| 층 | 역할 |
|---|---|
| `SKILLS_GUIDANCE` | 시스템 프롬프트에 “복잡한 작업 후 스킬로 저장하라” 상시 지시 |
| `skill_manage` | `SKILL.md`를 실제로 쓰는 도구 |
| `/learn` | 사용자가 트리거하면 대화/소스를 증류해 스킬 작성 |
| `background_review` | 턴 종료 후 백그라운드에서 “저장할 게 있나?” 검토 |

핵심 안내(개념):

- 복잡한 작업(도구 호출 다수), 까다로운 오류 수정, 비자명 워크플로 발견 후 → 스킬로 저장
- 기존 스킬이 오래되었거나 틀리면 → 즉시 patch
- `/learn`은 별도 엔진이 아니라, 작성 표준이 박힌 프롬프트를 일반 턴으로 주입하는 패턴

참고 코드 위치(hermes-agent 저장소):

- `agent/prompt_builder.py` — `SKILLS_GUIDANCE`
- `agent/learn_prompt.py` — `/learn` 프롬프트 빌더
- `agent/background_review.py` — 턴 후 백그라운드 리뷰
- `agent/turn_finalizer.py` — skill nudge / review 트리거
- `tools/skill_manager_tool.py` — `skill_manage`
- `website/docs/guides/work-with-skills.md` — 사용자 가이드

## Cursor에는 없는 것 / 있는 것

Cursor에는 Hermes의 `skill_manage` + `background_review` 같은 내장 자율 학습 루프가 없다.

대신 아래를 조합한다.

| Hermes | Cursor |
|---|---|
| `SKILLS_GUIDANCE` | User Rules / Project Rules / AGENTS.md |
| `skill_manage` | Write + `create-skill` 스킬 |
| `/learn` | 고정 프롬프트 / 커스텀 명령 |
| `background_review` | Hooks (`stop` / `sessionEnd`) + 별도 승격 턴 |
| `curator` | “스킬 정리” 스킬 + 수동 리뷰 |
| memory / session_search | Memories, Rules, inbox 파일 |

스킬 저장 위치:

- 프로젝트 공유: `.cursor/skills/<name>/SKILL.md`
- 개인: `~/.cursor/skills/<name>/SKILL.md`
- 금지: `~/.cursor/skills-cursor/` (Cursor 내장 스킬 영역)

## 구현 방법

### 1. 규칙으로 “언제 스킬로 남길지” 고정

프로젝트 또는 유저 규칙 예시:

```markdown
# Self-skill loop
작업 중 다음에 해당하면 스킬 후보를 제안하거나 작성한다:
- 5회 이상 도구 호출이 필요했던 해결
- 사용자가 수정/교정한 절차
- 프로젝트 특유 함정 (경로, 인코딩, Windows 배치 등)

작성 시:
1. create-skill 스킬을 따른다
2. Pitfalls에 시행착오를 구체적으로 적는다
3. 기본은 초안을 보여주고 확인받은 뒤 `.cursor/skills/<name>/SKILL.md`에 저장한다
```

자율성 수준은 프로젝트마다 선택:

- 안전: 초안 제안 → 사용자 승인 후 저장
- 공격적: 조건 충족 시 바로 저장 (오염 위험 큼)

### 2. `/learn` 흉내 (가장 안정적)

채팅에서 예:

> 방금 대화에서 배운 절차를 Cursor 스킬로 만들어.
> create-skill 형식을 지키고 Pitfalls에 실패한 시도도 넣어.
> 저장 위치는 `.cursor/skills/<name>/SKILL.md`.

또는 `.cursor/rules` / 커스텀 명령에 동일 프롬프트를 고정해 두고 `learn`이라고만 치게 한다.

이 경로가 캐시·비용·품질 면에서 가장 안전하다. Hermes의 `/learn`도 프롬프트 주입이다.

### 3. Hooks로 턴 끝 수집 (background_review에 가장 가까움)

권장 이벤트: `stop`, `sessionEnd`, `afterAgentResponse`, `sessionStart`

권장 흐름:

1. `stop` / `sessionEnd` 훅이 transcript 요약·피드백·실패 명령을 inbox에 append  
   예: `.cursor/learning/inbox.jsonl` 또는 `Analysis/YYYYMMDD-learning-inbox.md`
2. 다음 세션 시작(`sessionStart`) 또는 주기적으로 에이전트에게  
   “inbox를 읽어 스킬로 승격할지 판단하고 create-skill로 작성하라” 지시
3. 기본은 바로 SKILL.md를 쓰지 말고 inbox에만 쌓기 → 사람 승인 후 승격

본 작업과 경쟁하지 않게, “작업 중 끼어들기”보다 **세션 끝 수집 + 별도 승격 턴**이 맞다.

### 4. create-skill을 skill_manage처럼 쓰기

필수 섹션:

- **When to Use** — 트리거 문구
- **Procedure** — 최종 정답 절차
- **Pitfalls** — 실패한 시도·사용자 정정 (시행착오의 본체)

선택:

- `scripts/` — 반복 스크립트
- `references/` — 긴 참고자료

### 5. 피드백을 신호로 정의

| 신호 | 예 |
|---|---|
| 명시 피드백 | “아니야, UTF-8로”, “bat는 EOL CRLF” |
| 반복 실패 | 같은 명령 3회 실패 후 다른 방식으로 성공 |
| 승인/거절 | “그렇게 해”, “그 스킬 틀렸어” |
| 분석 노트 | `Analysis/YYYYMMDD-*.md`에 남긴 결론 |

규칙에 “이런 신호가 나오면 Pitfalls/Procedure를 갱신하라”고 쓰면 Hermes의 patch 습관과 같아진다.

## 현실적인 3단계

### A. 최소 (오늘 바로)

- Self-skill 규칙 1개
- 작업 끝나면 “스킬로 남겨줘” / `/learn` 프롬프트

### B. 반자동 (추천)

- 규칙
- `sessionEnd` 훅으로 inbox 적재
- 주 1회 “inbox → 스킬 승격” 세션

### C. 최대한 Hermes에 가깝게

- B + `stop` 훅에서 복잡도 휴리스틱(도구 호출 수·에러 횟수)으로 후보 follow-up
- curator 역할 스킬(오래된 agent-created 스킬 정리)

완전 무인 자동 작성은 가능하지만, 잘못된 스킬이 다음 세션을 오염시키기 쉽다.  
권장 기본값은 “제안 → 사용자 yes”.

## Analysis → Skill 승격 패턴

1. **수집**: 작업 결론을 `Analysis/YYYYMMDD-*.md`에 남긴다
2. **승격**: “이 Analysis를 `.cursor/skills/.../SKILL.md`로 만들어”
3. **루프 규칙**: “Analysis에 새 결론이 생기면 스킬 후보인지 묻고, 승인 시 create-skill로 작성”

다른 프로젝트에 이식할 때:

1. Self-skill Rule을 프로젝트에 복사
2. (선택) `.cursor/hooks.json` + inbox 훅 추가
3. `/learn` 프롬프트 템플릿을 규칙 또는 커스텀 명령으로 고정
4. 팀 공유가 필요하면 스킬을 `.cursor/skills/`에 커밋

## `/learn` 프롬프트 템플릿

```text
이번 대화(또는 내가 가리킨 소스)에서 재사용 가능한 절차를 Cursor Agent Skill로 증류해라.

요구사항:
1. create-skill 스킬의 SKILL.md 형식을 따른다
2. name은 lowercase-hyphenated
3. description은 짧고, 언제 쓸지 드러나게 쓴다
4. When to Use / Prerequisites / Procedure / Pitfalls / Verification 을 포함한다
5. Pitfalls에는 실패한 시도, 잘못된 가정, 사용자 정정을 구체적으로 적는다
6. 추측으로 API/플래그를 만들지 말고, 대화에서 확인된 사실만 쓴다
7. 기본은 초안을 보여주고 확인받은 뒤 `.cursor/skills/<name>/SKILL.md`에 저장한다
8. 기존 스킬이 이미 있으면 새로 만들지 말고 patch/갱신한다
```

## 주의사항

- 스킬은 절차 지식, 메모리는 사실 지식. 혼용하지 말 것
- 스킬은 좁고 구체적으로 (“모든 DevOps” X, “Python 앱 Fly.io 배포” O)
- 오래되어 틀린 스킬은 자산이 아니라 부채 — 사용 중 발견하면 즉시 갱신
- Prompt caching / 컨텍스트 오염을 피하려면, 본 작업 중간에 시스템 프롬프트를 바꾸지 말고 별도 승격 턴을 쓴다

## 문서 명명

분석·설명 md 파일은 `YYYYMMDD-<주제>.md` 형식으로 저장한다. (예: `20260729-cursor-self-skill-loop.md`)
