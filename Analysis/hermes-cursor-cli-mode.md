# Hermes CLI에서 Cursor ask/agent 변경

날짜: 2026-07-24

## 요약

`hermes-cursor-provider`에 일반 플러그인 + 사이드카 mode API를 추가해
Hermes CLI/`hermes` 채팅에서 ask↔agent를 바꿀 수 있다. 코어 패치 없음.

## 사용

```powershell
# 1회 설치
cd d:\GitHub\AI\hermes-cursor-provider
.\scripts\install-hermes-plugin.ps1 -Enable

# 터미널
hermes cursor mode
hermes cursor mode agent
hermes cursor mode ask
hermes cursor mode plan

# 대화형 CLI / 게이트웨이
/cursor-mode
/cursor-mode agent
/cursor-mode ask
```

## CLI 매핑 (중요)

Cursor Agent CLI의 `--mode` 허용값은 **`ask` / `plan`만**.  
`agent`는 플래그 값이 아니라 **`--mode` 생략(기본 동작)** 이다.

| Hermes 모드 | CLI argv |
|-------------|----------|
| ask | `--mode=ask` |
| plan | `--mode=plan` |
| agent | *(no --mode)* |

`--mode=agent`를 넘기면 CLI가 exit 1 → HTTP 502.

상태 파일: `$HERMES_HOME/cursor_mode` (내용 `ask` 또는 `agent`)  
사이드카는 요청마다 이 파일을 읽으므로 **Hermes/사이드카 재시작 불필요**.

## 해상 순서

1. 요청 explicit / 헤더 `X-Hermes-Cursor-Mode` / body `hermes_cursor_mode`
2. `$HERMES_HOME/cursor_mode` 파일
3. env `HERMES_CURSOR_MODE`
4. 기본 `ask`

## 구성

| 경로 | 역할 |
|------|------|
| `hermes_cursor_proxy/mode_state.py` | 파일·env 해상 |
| `GET\|POST /v1/cursor/mode` | 상태 조회·설정 |
| `hermes_cursor_plugin/` | `/cursor-mode`, `hermes cursor` |
| `plugins/model-providers/cursor/` | ProviderProfile (기존) |

플러그인은 `hermes plugins enable cursor` 필요 (opt-in).
