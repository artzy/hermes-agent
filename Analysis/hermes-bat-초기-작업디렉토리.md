# hermes.bat 초기 작업 디렉터리 (멀티폴더)

- **일시**: 2026-07-27 (멀티폴더: 2026-07-29)
- **대상**: `hermes.bat`

---

## 배경

로컬 CLI는 `os.getcwd()`를 주 작업 폴더로 쓴다.  
여러 폴더에 걸친 작업은 Hermes **Project**(primary + 추가 folders)로 묶는 것이 정석이다.  
`hermes.bat`는 기동 시 폴더 목록을 읽고 Project를 sync한 뒤 **primary로 cd** 해서 Hermes를 띄운다.

## 폴더 목록 우선순위

1. 환경변수 `HERMES_WORKDIRS` (`D:\a;D:\b`, 첫 항목 = primary)
2. `%HERMES_HOME%\workdirs` (한 줄에 한 경로, `#` 주석 가능)
3. 리포 루트 `hermes.workdirs` (로컬 전용, `.gitignore`)
4. bat 안 `HERMES_DEFAULT_WORKDIRS`
5. 단일 폴더 호환: `HERMES_WORKDIR` / `%HERMES_HOME%\workdir` / `hermes.workdir` / `HERMES_DEFAULT_WORKDIR`

없으면 호출 시점 cwd 유지 (Project sync 없음).

## Project sync

- 기본 slug/name: `local-workspace` / `Local Workspace`
- 없으면 `hermes project create … --use`, 있으면 `add-folder` + `set-primary` + `use`
- 끄기: `HERMES_SKIP_PROJECT=1`
- 이름/슬러그: `HERMES_PROJECT_NAME`, `HERMES_PROJECT_SLUG`
- Cursor proxy 스킵: `HERMES_SKIP_PROXY=1` (리다이렉트/테스트 시 `start` 대기 방지용으로 proxy는 `Start-Process`로 분리)

## 설정 예

```powershell
# A) 환경변수
$env:HERMES_WORKDIRS = "D:\PMT\DEV\HSUniv;D:\GitHub\AI\hermes-agent"
D:\GitHub\AI\hermes-agent\hermes.bat

# B) 체크아웃 옆 로컬 파일 (권장)
@"
D:\PMT\DEV\HSUniv
D:\GitHub\AI\hermes-agent
"@ | Set-Content -Encoding utf8 "D:\GitHub\AI\hermes-agent\hermes.workdirs"
```

기동 시 예:

```text
[workdir 1] D:\PMT\DEV\HSUniv
[workdir 2] D:\GitHub\AI\hermes-agent
[workdir] primary: D:\PMT\DEV\HSUniv  (2 folder(s), source=...)
[project] sync local-workspace
[project] active: local-workspace  primary=D:\PMT\DEV\HSUniv
```

CLI는 여전히 primary cwd 기준(`AGENTS.md` 등). 다른 폴더는 절대경로 / `terminal(workdir=…)` 로 접근. Desktop은 Project folders로 세션이 묶인다.
