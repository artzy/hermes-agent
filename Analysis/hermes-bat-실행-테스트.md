# hermes.bat 실행 테스트

- **일시**: 2026-07-29 14:39
- **대상**: `hermes.bat`
- **머신**: DESKTOP-PGNHAET

## 결과 요약

| # | 케이스 | exit | 판정 |
|---|--------|------|------|
| 1 | default HERMES_DEFAULT_WORKDIRS + --version | 0 | PASS |
| 2 | HERMES_WORKDIRS sync + --version | 0 | PASS |
| 3 | HERMES_SKIP_PROJECT=1 | 0 | PASS |
| 4 | missing folder error | 1 | PASS |
| 5 | hermes.workdirs file | 0 | PASS |
| 6 | project show local-workspace | 0 | PASS |

**합계**: 6 / 6 PASS

## 상세 로그

### 1. default HERMES_DEFAULT_WORKDIRS + --version — PASS (exit 0)

```text
[workdir 1] D:\PMT\DEV\HSUniv
[workdir 2] D:\GitHub\AI\hermes-agent
[workdir] primary: D:\PMT\DEV\HSUniv  (2 folder(s), source=HERMES_DEFAULT_WORKDIRS)
[project] sync local-workspace
[project] active: local-workspace  primary=D:\PMT\DEV\HSUniv
Hermes Agent v0.19.0 (2026.7.20) · upstream 226fd31b
Install directory: D:\GitHub\AI\hermes-agent
Install method: git
Python: 3.11.9
OpenAI SDK: 2.24.0
Up to date
```

### 2. HERMES_WORKDIRS sync + --version — PASS (exit 0)

```text
[workdir 1] D:\PMT\DEV\HSUniv
[workdir 2] D:\GitHub\AI\hermes-agent
[workdir] primary: D:\PMT\DEV\HSUniv  (2 folder(s), source=env:HERMES_WORKDIRS)
[project] sync local-workspace
[project] active: local-workspace  primary=D:\PMT\DEV\HSUniv
Hermes Agent v0.19.0 (2026.7.20) · upstream 226fd31b
Install directory: D:\GitHub\AI\hermes-agent
Install method: git
Python: 3.11.9
OpenAI SDK: 2.24.0
Up to date
```

### 3. HERMES_SKIP_PROJECT=1 — PASS (exit 0)

```text
[workdir 1] D:\PMT\DEV\HSUniv
[workdir 2] D:\GitHub\AI\hermes-agent
[workdir] primary: D:\PMT\DEV\HSUniv  (2 folder(s), source=env:HERMES_WORKDIRS)
Hermes Agent v0.19.0 (2026.7.20) · upstream 226fd31b
Install directory: D:\GitHub\AI\hermes-agent
Install method: git
Python: 3.11.9
OpenAI SDK: 2.24.0
Up to date
```

### 4. missing folder error — PASS (exit 1)

```text
[workdir 1] D:\PMT\DEV\HSUniv
[error] Work folder not found:
  D:\this\path\does\not\exist
Source: env:HERMES_WORKDIRS
```

### 5. hermes.workdirs file — PASS (exit 0)

```text
[workdir 1] D:\PMT\DEV\HSUniv
[workdir 2] D:\GitHub\AI\hermes-agent
[workdir] primary: D:\PMT\DEV\HSUniv  (2 folder(s), source=d:\GitHub\AI\hermes-agent\hermes.workdirs)
[project] sync local-workspace
[project] active: local-workspace  primary=D:\PMT\DEV\HSUniv
Hermes Agent v0.19.0 (2026.7.20) · upstream 226fd31b
Install directory: D:\GitHub\AI\hermes-agent
Install method: git
Python: 3.11.9
OpenAI SDK: 2.24.0
Up to date
```

### 6. project show local-workspace — PASS (exit 0)

```text
[workdir 1] D:\PMT\DEV\HSUniv
[workdir 2] D:\GitHub\AI\hermes-agent
[workdir] primary: D:\PMT\DEV\HSUniv  (2 folder(s), source=env:HERMES_WORKDIRS)
[project] sync local-workspace
[project] active: local-workspace  primary=D:\PMT\DEV\HSUniv
local-workspace  [p_c0a474f6]
  name:    Local Workspace
  primary: D:\PMT\DEV\HSUniv
  folders:
    * D:\PMT\DEV\HSUniv
      D:\GitHub\AI\hermes-agent
```

