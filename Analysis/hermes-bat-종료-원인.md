# hermes.bat 실행 직후 종료

- **일시**: 2026-09-24
- **대상**: `hermes.bat`

## 원인

프로젝트 이름/slug를 환경변수로 유지하도록 바꾼 줄은 종료 원인이 아니다.

기본 작업 폴더 `D:\PMT\DEV\HSUniv`가 이 PC에 없다. 목록에 없는 경로가 있으면 `err_workdir_missing`으로 `exit /b 1` 해서, 더블클릭 창이 바로 닫힌다. `hermes.exe`까지 도달하지 않는다.

## 수정

`HERMES_DEFAULT_WORKDIRS` / `HERMES_DEFAULT_WORKDIR`에서만 없는 폴더를 경고 후 건너뛴다. 사용자가 지정한 경로가 없으면 예전처럼 오류로 끝낸다.

건너뛴 뒤 남은 기본 폴더는 `D:\GitHub\AI\hermes-agent`이다. `--version` 확인 시 종료 코드 0.
