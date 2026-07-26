# Hermes ↔ Cursor 연동 가이드

- **작성일**: 2026-07-26
- **대상**: Windows + 로컬 `hermes-agent` 체크아웃

연동은 **방향이 세 갈래**다. 목적에 맞는 경로만 고르면 된다.

| 목적 | 방향 | 방법 |
|---|---|---|
| Cursor 안에서 Telegram/Discord 등 메시지 다루기 | Cursor → Hermes | `hermes mcp serve` (MCP) |
| Hermes가 프로젝트 `.cursor` 규칙을 읽게 하기 | 규칙 공유 | cwd에서 Hermes 실행 (자동) |
| Hermes의 LLM을 Cursor Agent로 쓰기 | Hermes → Cursor | 외부 `hermes-cursor-provider` 사이드카 |
| Cursor를 IDE 호스트로 Hermes 코딩 에이전트 붙이기 | ACP | **공식 미지원** (Zed/VS Code ACP는 됨) |

---

## A. Cursor → Hermes (MCP 메시징 브리지) — 가장 쉬운 공식 경로

Hermes가 MCP **서버**가 되고, Cursor가 클라이언트로 붙는다.  
코딩 루프 대체가 아니라 **메시징 채널 브리지**다 (gateway가 떠 있어야 송신 가능).

### 1) Hermes 준비

```powershell
cd d:\Github\AI\hermes-agent
.\.venv\Scripts\hermes.exe gateway   # 플랫폼 연결 시
# 또는 이미 gateway 서비스가 돌고 있으면 생략
```

### 2) Cursor MCP 설정

파일: `%USERPROFILE%\.cursor\mcp.json`  
`mcpServers`에 추가:

```json
{
  "mcpServers": {
    "hermes": {
      "command": "d:\\Github\\AI\\hermes-agent\\.venv\\Scripts\\hermes.exe",
      "args": ["mcp", "serve"]
    }
  }
}
```

PATH에 `hermes`가 있으면 `"command": "hermes"` 로 단순화 가능.

### 3) Cursor 재시작 후 확인

Settings → MCP에서 `hermes` 서버가 초록인지 확인.  
노출 도구 예: `conversations_list`, `messages_read`, `messages_send`, `channels_list`, `events_poll` …

문서: `website/docs/user-guide/features/mcp.md` → “Running Hermes as an MCP server”.

---

## B. 규칙 공유 (별도 설치 없음)

Hermes를 **그 프로젝트 cwd**에서 돌리면 `.cursorrules` / `.cursor/rules/*.mdc`를 자동으로 시스템 프롬프트에 넣는다.

```powershell
cd d:\path\to\your\project
d:\Github\AI\hermes-agent\.venv\Scripts\hermes.exe
```

우선순위(프로젝트 컨텍스트 한 종류만): `.hermes.md` → `AGENTS.md` → `CLAUDE.md` → `.cursorrules`.  
Cursor 터미널에서 바로 `hermes`를 켜도 동일.

---

## C. Hermes → Cursor Agent (추론 백엔드) — 반대 방향

코어에 Cursor를 넣지 않는 정책(#16282). **형제 레포** `hermes-cursor-provider` + OpenAI-compat 사이드카.

### 필요 조건

1. Cursor Agent CLI: `irm 'https://cursor.com/install?win32=true' | iex` → `agent` on PATH  
   (IDE의 `cursor.cmd`와 다름)
2. `CURSOR_API_KEY` 또는 `agent login`
3. 레포: `d:\Github\AI\hermes-cursor-provider` (`artzy/hermes-cursor-provider`, 2026-07-26 설치됨)

### 기동

```bat
d:\Github\AI\hermes-agent\start_hermes_cursor_proxy.bat
```

기본 엔드포인트: `http://127.0.0.1:2389/v1`

```powershell
hermes model   # Cursor Agent 선택
# 모드: agent(기본, Cursor 파일·셸 — 이중 에이전트 주의) / ask(Hermes가 도구 소유)
hermes cursor mode agent
```

상세: `Analysis/hermes-cursor-provider.md`, `hermes-cursor-cli-mode.md`, `hermes-cursor-503-fix.md`.

---

## D. ACP (참고)

```powershell
uv sync --extra acp   # 또는 pip install -e ".[acp]"
hermes acp
```

Zed / VS Code(ACP Client) / JetBrains용. **Cursor는 공식 ACP 호스트로 문서화되지 않음.**

---

## 추천 선택

| 하고 싶은 것 | 선택 |
|---|---|
| Cursor 채팅에서 Hermes 메시징 쓰기 | **A. MCP** |
| Cursor 규칙을 Hermes에도 적용 | **B** |
| Hermes CLI/게이트웨이 두뇌로 Cursor 모델 쓰기 | **C. 사이드카** |
| Cursor 안에서 Hermes를 메인 코딩 에이전트로 | 불가에 가까움 → Zed/VS Code ACP 또는 터미널에서 `hermes`/`hermes --tui` |

---

## 트러블슈팅 빠른표

| 증상 | 조치 |
|---|---|
| MCP `hermes` 안 뜸 | `mcp.json` 경로·재시작; `hermes mcp serve` 수동 실행해 stderr 확인 |
| `messages_send` 실패 | `hermes gateway` + 플랫폼 토큰 |
| Cursor provider 503 | IDE `cursor.cmd` 말고 **Agent CLI** 설치; 사이드카 health 확인 |
| 모델 404 | `hermes model`로 provider/model 고정 |
