@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Hermes CLI launcher (Windows) — multi-folder workspace aware
REM Usage: hermes.bat [args...]
REM Example: hermes.bat --version
REM          hermes.bat cursor mode
REM          hermes.bat -z "hello"
REM
REM Work folders (first = primary cwd; rest attached to a Hermes Project):
REM   1) env HERMES_WORKDIRS=D:\a;D:\b
REM   2) %HERMES_HOME%\workdirs          (one path per line; # comments ok)
REM   3) %AGENT_ROOT%\hermes.workdirs    (local file next to this bat; gitignored)
REM   4) HERMES_DEFAULT_WORKDIRS below   (semicolon-separated)
REM Single-folder fallback (compat):
REM   HERMES_WORKDIR / %HERMES_HOME%\workdir / hermes.workdir / HERMES_DEFAULT_WORKDIR
REM
REM Project sync (create/add-folder/use) runs unless HERMES_SKIP_PROJECT=1.
REM Override name/slug: HERMES_PROJECT_NAME / HERMES_PROJECT_SLUG

set "HERMES_DEFAULT_WORKDIR=D:\PMT\DEV\HSUniv"
set "HERMES_DEFAULT_WORKDIRS=D:\PMT\DEV\HSUniv;D:\GitHub\AI\hermes-agent"
set "HERMES_PROJECT_NAME=Local Workspace"
set "HERMES_PROJECT_SLUG=local-workspace"

set "AGENT_ROOT=%~dp0"
if "%AGENT_ROOT:~-1%"=="\" set "AGENT_ROOT=%AGENT_ROOT:~0,-1%"

REM Start cursor proxy in its own console. Plain `start` waits when this bat's
REM stdout is redirected (tests/pipes), so launch via PowerShell Start-Process
REM (returns immediately, WindowStyle Normal = visible console).
REM Skip with HERMES_SKIP_PROXY=1
if /i not "%HERMES_SKIP_PROXY%"=="1" (
  powershell -NoProfile -Command "Start-Process -FilePath '%AGENT_ROOT%\start_hermes_cursor_proxy.bat' -WorkingDirectory '%AGENT_ROOT%' -WindowStyle Normal"
  if errorlevel 1 echo [warn] failed to start start_hermes_cursor_proxy.bat
  ping -n 4 127.0.0.1 >nul
)

set "HERMES_EXE="
if exist "%AGENT_ROOT%\.venv\Scripts\hermes.exe" set "HERMES_EXE=%AGENT_ROOT%\.venv\Scripts\hermes.exe"
if not defined HERMES_EXE if exist "%AGENT_ROOT%\venv\Scripts\hermes.exe" set "HERMES_EXE=%AGENT_ROOT%\venv\Scripts\hermes.exe"
if not defined HERMES_EXE goto :err_no_hermes

REM Put venv Scripts first so child tools see the same hermes/python.
set "PATH=%AGENT_ROOT%\.venv\Scripts;%AGENT_ROOT%\venv\Scripts;%PATH%"

REM Default Hermes home on this machine if unset (profiles / config / plugins).
if not defined HERMES_HOME if defined LOCALAPPDATA (
  if exist "%LOCALAPPDATA%\hermes\config.yaml" set "HERMES_HOME=%LOCALAPPDATA%\hermes"
)

if not defined HERMES_PROJECT_NAME set "HERMES_PROJECT_NAME=Local Workspace"
if not defined HERMES_PROJECT_SLUG set "HERMES_PROJECT_SLUG=local-workspace"

REM Resolve folder list into a temp file (one absolute-ish path per line).
set "WORKDIRS_FILE=%TEMP%\hermes-workdirs-%RANDOM%%RANDOM%.txt"
if exist "%WORKDIRS_FILE%" del /f /q "%WORKDIRS_FILE%" >nul 2>&1

set "WORKDIRS_SRC="
if defined HERMES_WORKDIRS (
  set "WORKDIRS_SRC=env:HERMES_WORKDIRS"
  call :split_semicolons "%HERMES_WORKDIRS%" "%WORKDIRS_FILE%"
) else if defined HERMES_HOME if exist "%HERMES_HOME%\workdirs" (
  set "WORKDIRS_SRC=%HERMES_HOME%\workdirs"
  call :copy_workdirs_file "%HERMES_HOME%\workdirs" "%WORKDIRS_FILE%"
) else if exist "%AGENT_ROOT%\hermes.workdirs" (
  set "WORKDIRS_SRC=%AGENT_ROOT%\hermes.workdirs"
  call :copy_workdirs_file "%AGENT_ROOT%\hermes.workdirs" "%WORKDIRS_FILE%"
) else if defined HERMES_DEFAULT_WORKDIRS (
  set "WORKDIRS_SRC=HERMES_DEFAULT_WORKDIRS"
  call :split_semicolons "%HERMES_DEFAULT_WORKDIRS%" "%WORKDIRS_FILE%"
) else if defined HERMES_WORKDIR (
  set "WORKDIRS_SRC=env:HERMES_WORKDIR"
  call :append_workdir_line "%HERMES_WORKDIR%" "%WORKDIRS_FILE%"
) else if defined HERMES_HOME if exist "%HERMES_HOME%\workdir" (
  set "WORKDIRS_SRC=%HERMES_HOME%\workdir"
  set /p _ONE=<"%HERMES_HOME%\workdir"
  call :append_workdir_line "!_ONE!" "%WORKDIRS_FILE%"
  set "_ONE="
) else if exist "%AGENT_ROOT%\hermes.workdir" (
  set "WORKDIRS_SRC=%AGENT_ROOT%\hermes.workdir"
  set /p _ONE=<"%AGENT_ROOT%\hermes.workdir"
  call :append_workdir_line "!_ONE!" "%WORKDIRS_FILE%"
  set "_ONE="
) else if defined HERMES_DEFAULT_WORKDIR (
  set "WORKDIRS_SRC=HERMES_DEFAULT_WORKDIR"
  call :append_workdir_line "%HERMES_DEFAULT_WORKDIR%" "%WORKDIRS_FILE%"
)

if not exist "%WORKDIRS_FILE%" goto :launch_no_workdir

set "HERMES_PRIMARY="
set "FOLDER_COUNT=0"
set "CREATE_ARGS="
for /f "usebackq tokens=* delims=" %%L in ("%WORKDIRS_FILE%") do (
  set "LINE=%%L"
  set "LINE=!LINE:"=!"
  for /f "tokens=* delims= " %%A in ("!LINE!") do set "LINE=%%A"
  if not "!LINE!"=="" (
    if not exist "!LINE!" (
      set "BAD_WORKDIR=!LINE!"
      goto :err_workdir_missing
    )
    set /a FOLDER_COUNT+=1
    if not defined HERMES_PRIMARY set "HERMES_PRIMARY=!LINE!"
    set "CREATE_ARGS=!CREATE_ARGS! "!LINE!""
    echo [workdir !FOLDER_COUNT!] !LINE!
  )
)

if not defined HERMES_PRIMARY (
  del /f /q "%WORKDIRS_FILE%" >nul 2>&1
  goto :launch_no_workdir
)

echo [workdir] primary: !HERMES_PRIMARY!  ^(!FOLDER_COUNT! folder^(s^), source=!WORKDIRS_SRC!^)

REM Sync Hermes Project so Desktop / project tools see all folders.
if /i not "%HERMES_SKIP_PROJECT%"=="1" if !FOLDER_COUNT! GEQ 1 (
  call :ensure_project
  if errorlevel 1 (
    del /f /q "%WORKDIRS_FILE%" >nul 2>&1
    endlocal & exit /b 1
  )
)

cd /d "!HERMES_PRIMARY!" 2>nul || goto :err_workdir_cd

del /f /q "%WORKDIRS_FILE%" >nul 2>&1
goto :run_hermes

:launch_no_workdir
if exist "%WORKDIRS_FILE%" del /f /q "%WORKDIRS_FILE%" >nul 2>&1
echo [workdir] ^(caller cwd^) !CD!

:run_hermes
"%HERMES_EXE%" %*
set "RC=%ERRORLEVEL%"
endlocal & exit /b %RC%

:err_no_hermes
echo [error] hermes.exe not found.
echo   Expected: %AGENT_ROOT%\.venv\Scripts\hermes.exe
echo   Run:  cd /d "%AGENT_ROOT%" ^& uv sync
endlocal & exit /b 1

:err_workdir_missing
echo [error] Work folder not found:
echo   !BAD_WORKDIR!
echo Source: !WORKDIRS_SRC!
if exist "%WORKDIRS_FILE%" del /f /q "%WORKDIRS_FILE%" >nul 2>&1
endlocal & exit /b 1

:err_workdir_cd
echo [error] Cannot cd to primary workdir: !HERMES_PRIMARY!
if exist "%WORKDIRS_FILE%" del /f /q "%WORKDIRS_FILE%" >nul 2>&1
endlocal & exit /b 1

REM ----- helpers -----

:split_semicolons
set "_SRC=%~1"
set "_DST=%~2"
if exist "%_DST%" del /f /q "%_DST%" >nul 2>&1
:split_loop
if not defined _SRC goto :eof
for /f "tokens=1* delims=;" %%A in ("!_SRC!") do (
  call :append_workdir_line "%%A" "%_DST%"
  set "_SRC=%%B"
)
goto :split_loop

:copy_workdirs_file
set "_SRC=%~1"
set "_DST=%~2"
if exist "%_DST%" del /f /q "%_DST%" >nul 2>&1
for /f "usebackq eol=# tokens=* delims=" %%L in ("%_SRC%") do (
  call :append_workdir_line "%%L" "%_DST%"
)
goto :eof

:append_workdir_line
set "_LINE=%~1"
set "_DST=%~2"
if not defined _LINE goto :eof
set "_LINE=%_LINE:"=%"
for /f "tokens=* delims= " %%A in ("%_LINE%") do set "_LINE=%%A"
if "%_LINE%"=="" goto :eof
>>"%_DST%" echo(%_LINE%
goto :eof

:ensure_project
"%HERMES_EXE%" project show "%HERMES_PROJECT_SLUG%" >nul 2>&1
if errorlevel 1 (
  echo [project] create %HERMES_PROJECT_SLUG%
  "%HERMES_EXE%" project create "%HERMES_PROJECT_NAME%" !CREATE_ARGS! --slug "%HERMES_PROJECT_SLUG%" --use
  if errorlevel 1 (
    echo [error] hermes project create failed
    exit /b 1
  )
) else (
  echo [project] sync %HERMES_PROJECT_SLUG%
  for /f "usebackq tokens=* delims=" %%L in ("%WORKDIRS_FILE%") do (
    set "LINE=%%L"
    set "LINE=!LINE:"=!"
    for /f "tokens=* delims= " %%A in ("!LINE!") do set "LINE=%%A"
    if not "!LINE!"=="" (
      "%HERMES_EXE%" project add-folder "%HERMES_PROJECT_SLUG%" "!LINE!" >nul
    )
  )
  "%HERMES_EXE%" project set-primary "%HERMES_PROJECT_SLUG%" "!HERMES_PRIMARY!" >nul
  if errorlevel 1 (
    echo [error] hermes project set-primary failed
    exit /b 1
  )
  "%HERMES_EXE%" project use "%HERMES_PROJECT_SLUG%" >nul
  if errorlevel 1 (
    echo [error] hermes project use failed
    exit /b 1
  )
)
echo [project] active: %HERMES_PROJECT_SLUG%  primary=!HERMES_PRIMARY!
exit /b 0
