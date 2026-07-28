# hermes.bat 초기 작업 디렉터리

- **일시**: 2026-07-27
- **대상**: `hermes.bat`

---

## 배경

로컬 CLI는 `os.getcwd()`를 작업 폴더로 쓴다 (`terminal.cwd`는 메시징/gateway용).  
Windows에서 bat/바로가기로 띄우면 호출 cwd가 제각각이라, 런처에서 초기 디렉터리를 고를 수 있게 했다.

## 우선순위

1. 환경변수 `HERMES_WORKDIR`
2. `%HERMES_HOME%\workdir` (한 줄 경로 파일)
3. 리포 루트 `hermes.workdir` (로컬 전용, `.gitignore`에 추가)
4. 없으면 호출 시점 cwd 유지

## 설정 예

```powershell
# A) 환경변수 / 바로가기
$env:HERMES_WORKDIR = "D:\GitHub\AI\MyProject"
D:\GitHub\AI\hermes-agent\hermes.bat

# B) Hermes 홈 (권장 — 프로필과 같이 둠)
Set-Content "$env:LOCALAPPDATA\hermes\workdir" "D:\GitHub\AI\MyProject"

# C) 체크아웃 옆 로컬 파일
Set-Content "D:\GitHub\AI\hermes-agent\hermes.workdir" "D:\GitHub\AI\MyProject"
```

기동 시 `[workdir] D:\...` 한 줄이 출력된다.

## 검증

| 케이스 | 결과 |
|--------|------|
| `HERMES_WORKDIR` | ✅ `[workdir]` 후 `--version` |
| `hermes.workdir` | ✅ |
| `%HERMES_HOME%\workdir` | ✅ |
| 없는 경로 | ✅ 오류 메시지 후 **exit 1** |

참고: `exit /b`를 `( )` 블록 안에 두면 ERRORLEVEL이 0으로 남는 cmd 함정이 있어, 오류 경로는 `goto` + 라벨로 처리했다.
