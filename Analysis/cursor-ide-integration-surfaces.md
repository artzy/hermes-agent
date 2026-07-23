# Hermes ↔ Cursor / IDE 통합 표면 조사

조사일: 2026-07-23  
대상: `d:\GitHub\AI\hermes-agent`

## 한 줄 결론

Hermes는 **ACP 서버(에이전트)** 와 **메시징 MCP 서버** 를 이미 갖고 있다. Cursor는 문서상 MCP **클라이언트**로 Hermes 메시징 브리지를 쓸 수 있고, ACP **클라이언트**로는 공식 지원되지 않는다. Cursor를 Hermes의 추론 백엔드로 넣는 in-tree 작업은 정책상 거절된 상태다.

---

## 1. ACP (`acp_adapter/`)

### 프로토콜

- **Agent Client Protocol** (Zed Industries) — JSON-RPC over **stdio**
- Python 패키지: `agent-client-protocol==0.9.0` (`pyproject.toml` optional extra `[acp]`)
- 부트: `acp.run_agent(HermesACPAgent(), use_unstable_protocol=True)`
- stdout = ACP 프레임, stderr = 로그

### 실행 방법

| 명령 | 비고 |
|------|------|
| `hermes acp` | 메인 CLI (`hermes_cli/main.py` → `cmd_acp` → `acp_adapter.entry.main`) |
| `hermes-acp` | console script → `acp_adapter.entry:main` |
| `python -m acp_adapter` | 동일 |
| `hermes acp --check` / `--version` / `--setup` / `--setup-browser` | 비대화형 점검·프로바이더·브라우저 부트스트랩 |

의존성: `pip install -e '.[acp]'` (또는 설치 시 `[all]` extras에 포함).

Zed 레지스트리: `uvx --from 'hermes-agent[acp]==<ver>' hermes-acp`  
매니페스트: `acp_registry/agent.json`

### 핵심 파일

| 파일 | 역할 |
|------|------|
| `acp_adapter/entry.py` | CLI, env 로드, MCP discovery, `acp.run_agent` |
| `acp_adapter/server.py` | `HermesACPAgent` — initialize/auth/session/prompt |
| `acp_adapter/session.py` | SessionManager + SessionDB 영속화, cwd→task 바인딩 |
| `acp_adapter/events.py` | AIAgent 콜백 → ACP `session_update` |
| `acp_adapter/permissions.py` | 위험 터미널 승인 브리지 |
| `acp_adapter/edit_approval.py` | 파일 편집 사전 승인 (ContextVar, ACP 전용) |
| `acp_adapter/tools.py` | Hermes 도구 → ACP ToolKind / Diff 렌더 |
| `acp_adapter/auth.py` | 프로바이더 감지 + terminal setup auth |
| `toolsets.py` → `hermes-acp` | 에디터용 큐레이션 도구셋 |

### 지원 능력 (서버가 광고하는 것)

`initialize` → `AgentCapabilities`:

- `load_session`, session `fork` / `list` / `resume`
- `prompt_capabilities.image=True`
- auth methods (설정된 프로바이더 + `hermes-setup` 터미널 auth)

세션/프롬프트:

- `new_session` / `load_session` / `resume_session` / `fork_session` / `list_sessions` / `cancel`
- `prompt` — 텍스트·이미지·리소스 블록; 슬래시 커맨드 로컬 처리; 동시 프롬프트 큐잉; `/steer` idle rewrite
- 스트리밍: agent message / thought chunks, tool start/progress/complete, usage, available commands
- 에디터 cwd를 `register_task_env_overrides`로 파일/터미널에 바인딩 (WSL↔Windows 경로 번역)
- 세션별 MCP 서버 등록 (`_register_session_mcp_servers`) — **주의:** toolset 갱신 시 `_invalidate_system_prompt` 호출 가능 (캐시 영향)
- 승인: `allow_once` / `allow_session` / `allow_always` / `deny`
- 모델/모드/`set_config_option` RPC
- AIAgent는 `ThreadPoolExecutor`(max 4)에서 동기 실행

### `hermes-acp` 도구셋 (포함 / 제외)

포함: web, terminal/process, file tools, vision, skills, browser, todo/memory, session_search, execute_code, delegate_task  

의도적 제외: messaging (`send_message`), cronjob, clarify, TTS 등 에디터 UX에 안 맞는 것

### 공식 에디터 문서

- VS Code: ACP Client 확장 (`formulahendry.acp-client`) + `acp.agents` / 빌트인 Hermes 목록
- Zed: ACP Registry + 커스텀 `agent_servers`
- JetBrains: ACP 플러그인 + `acp_registry` 경로

**Cursor는 ACP 사용자 문서에 등장하지 않음.**

문서:

- `website/docs/user-guide/features/acp.md`
- `website/docs/developer-guide/acp-internals.md`
- `website/docs/developer-guide/programmatic-integration.md`

---

## 2. Cursor 관련 언급 (통합 vs 호환)

| 성격 | 위치 | 내용 |
|------|------|------|
| MCP 클라이언트로서 Cursor | `mcp_serve.py`, `website/docs/user-guide/features/mcp.md` | Claude Code / **Cursor** / Codex가 `hermes mcp serve` 사용 가능하다고 명시 |
| 프로젝트 규칙 호환 | `agent/prompt_builder.py`, prompt-assembly docs | `.cursorrules`, `.cursor/rules/*.mdc`를 시스템 프롬프트에 주입 |
| 터미널 UX | TUI `/terminal-setup`, keybinding docs | VS Code / **Cursor** / Windsurf용 키바인딩 |
| MCP env 문법 | `tools/mcp_tool.py` | Cursor식 `${env:VAR}` 수용 |
| UI “커서” | Ink/TUI | 텍스트 커서 — IDE 무관 |
| 정책 / 이슈 | GitHub #16282 등 | Cursor Agent CLI를 **Hermes 추론 백엔드(ACP harness)** 로 in-tree 추가 → **닫힘** (standalone plugin만) |

ACP.org 에이전트 목록에는 Hermes와 Cursor가 **둘 다 ACP Agent(서버)** 로 올라 있음. Cursor는 현재 Hermes를 호스팅하는 ACP Client로 문서화되지 않음.

---

## 3. MCP — Hermes가 서버가 되는 경로

### A. `hermes mcp serve` (`mcp_serve.py`) — Cursor용으로 문서화됨

```bash
hermes mcp serve
hermes mcp serve --verbose
```

CLI: `hermes_cli/subcommands/mcp.py` → `mcp_command` → `run_mcp_server()`.

**역할:** 코딩 에이전트 루프가 아님. **메시징 채널 브리지** (OpenClaw 스타일 10툴).

| Tool | 기능 |
|------|------|
| `conversations_list`, `conversation_get` | 세션 목록/상세 |
| `messages_read`, `attachments_fetch` | 히스토리/첨부 |
| `events_poll`, `events_wait` | 라이브 이벤트 |
| `messages_send` | 플랫폼 송신 (gateway 필요) |
| `channels_list` | 대상 나열 |
| `permissions_list_open`, `permissions_respond` | 승인 |

Cursor `mcp.json` 예시 (문서와 동일 패턴):

```json
{
  "mcpServers": {
    "hermes": {
      "command": "hermes",
      "args": ["mcp", "serve"]
    }
  }
}
```

제한: stdio only; 송신은 gateway 필요; 텍스트 송신 위주; Hermes를 Cursor Agent로 대체하지 않음.

### B. `agent/transports/hermes_tools_mcp_server.py`

Codex app-server 런타임 전용 — Hermes 도구 일부를 Codex subprocess에 MCP로 노출. Cursor 대상이 아님.

### C. Hermes = MCP **클라이언트**

`config.yaml`의 `mcp_servers` + `tools/mcp_tool.py` — Cursor와 무관한 일반 MCP 클라이언트 경로.

---

## 4. TUI gateway / `hermes serve` / dashboard

| 표면 | 진입점 | Cursor 적합성 |
|------|--------|----------------|
| TUI gateway JSON-RPC | `tui_gateway/server.py`, `tui_gateway/entry.py`, `tui_gateway/ws.py` | Ink TUI / dashboard / Desktop용. 외부 호스트가 stdio(또는 dashboard `/api/ws`)로 붙을 수 있으나 Cursor용 어댑터 없음. 로컬 OS trust. |
| `hermes serve` | headless dashboard 백엔드 (`cmd_dashboard`, `headless_backend=True`) | Desktop/API용; 브라우저 SPA 비활성. Cursor 연결용 아님. |
| OpenAI API | `gateway/platforms/api_server.py` | HTTP Chat Completions / Responses — “커스텀 OpenAI base”로 우회 가능하나 IDE 네이티브 UX(diff/승인) 없음. |

Programmatic 가이드 권장:

1. IDE + ACP → ACP  
2. 풀 기능 커스텀 호스트 → TUI gateway  
3. HTTP/프론트엔드 → API server  

`--mode rpc` 없음.

---

## 5. Cursor 관점: 가능 / 갭

### 가능 (오늘)

1. **Cursor → Hermes MCP**: 메시징/승인 브리지 (`hermes mcp serve`)
2. **Cursor 워크스페이스 규칙 → Hermes**: `.cursorrules` / `.cursor/rules` 자동 로드 (Hermes가 그 cwd에서 돌 때)
3. **터미널에서 Hermes**: Cursor 내장 터미널 + TUI keybinding 배려
4. **이론상 ACP**: Cursor가 ACP Client를 지원하거나 커뮤니티 브리지가 있으면 `hermes acp`와 동일 계약 — **공식 문서/지원 없음**
5. **이론상 API**: Cursor Custom Model → Hermes API server — 도구/승인 UX 빈약

### 갭

- Cursor를 공식 ACP 호스트로 문서화·검증하지 않음
- `hermes mcp serve`는 에이전트 루프/파일/터미널을 노출하지 않음
- Cursor Agent를 Hermes 프로바이더로 in-tree 통합 거절 (standalone plugin만)
- TUI gateway / `hermes serve`에 Cursor 플러그인 없음
- ACP 세션 MCP 등록 시 system prompt invalidate → 프롬프트 캐시 깨질 수 있음

---

## 6. 통합 접근 (Hermes 설계 적합도 순)

### 1순위 — Cursor MCP → `hermes mcp serve` (메시징)

- 이미 문서화·구현됨  
- 코어 도구셋 확대 없음  
- 적합: Cursor가 Telegram/Discord 등을 Hermes 경유로 다룰 때  

### 2순위 — Cursor를 ACP Client로 (또는 얇은 브리지) → `hermes acp`

- IDE-native 코딩 에이전트에 맞는 1등 프로토콜  
- 새 코어 도구 불필요; 어댑터/설정만  
- Cursor 네이티브 ACP Client 부재가 리스크  

### 3순위 — Standalone plugin: Cursor Agent CLI를 Hermes **provider**로

- #16282 정책과 일치 (in-tree 금지, `~/.hermes/plugins` / pip)  
- 방향이 반대(Hermes가 Cursor를 호출) — “Cursor 안에서 Hermes”와 다름  

### 4순위 — TUI gateway / API server 커스텀 Cursor 확장

- 기능은 가장 풍부하나 Cursor 확장 유지보수 + 로컬 IPC trust  
- footprint/유지비 큼 → 최후 수단  

**비권장:** Cursor용 새 코어 model tool 추가, 코어에 Cursor 특수 케이스 hardcode.

---

## 7. AGENTS.md 제약 (설계에 영향)

1. **Per-conversation prompt caching** — 대화 중 toolset/system prompt 변경 금지. ACP MCP 등록의 `_invalidate_system_prompt`는 세션 시작 시점으로 제한해야 함.  
2. **Narrow waist / Footprint Ladder** — 에디터 기능은 ACP/플러그인/스킬; 코어 도구 최후.  
3. **No new HERMES_* for non-secrets** — 동작은 `config.yaml`.  
4. **Third-party product plugins in-tree 금지** — Cursor 전용 코어 플러그인 디렉터리 PR은 닫힐 가능성 큼 → standalone.  
5. **Plugins must not patch core** — 필요하면 generic surface 확장.  
6. **SECURITY** — ACP/TUI는 로컬 사용자 trust; 네트워크 노출 시 allowlist/auth 필수.  
7. **Alternation / byte-stable system prompt** — IDE 브리지도 메시지 역할·프롬프트 안정성 유지.

---

## 8. 진입점 체크리스트

```text
# 에디터 에이전트 (VS Code / Zed / JetBrains; Cursor는 비공식)
hermes acp
hermes-acp
python -m acp_adapter

# Cursor MCP (메시징)
hermes mcp serve

# 풀 RPC 호스트 (커스텀 UI)
# Ink: hermes --tui → tui_gateway stdio
# Dashboard WS: hermes dashboard → /api/ws
# Headless: hermes serve

# HTTP OpenAI-compat
# gateway api_server platform / docs: api-server.md
```

관련 docs:

- `website/docs/user-guide/features/acp.md`
- `website/docs/developer-guide/acp-internals.md`
- `website/docs/developer-guide/programmatic-integration.md`
- `website/docs/user-guide/features/mcp.md` (§ Running Hermes as an MCP server)
- `website/docs/integrations/index.md` (IDE & Editor Integration)
