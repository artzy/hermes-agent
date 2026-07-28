@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Hermes CLI launcher (Windows)
REM Usage: hermes.bat [args...]
REM Example: hermes.bat --version
REM          hermes.bat cursor mode
REM          hermes.bat -z "hello"
REM
REM Initial working directory (optional — leave unset to keep the caller's cwd):
REM   1) env HERMES_WORKDIR=D:\path\to\project
REM   2) %HERMES_HOME%\workdir          (one-line path file)
REM   3) %AGENT_ROOT%\hermes.workdir    (local file next to this bat; gitignored)
REM   4) HERMES_DEFAULT_WORKDIR below
REM   5) otherwise: caller's current directory
set "HERMES_DEFAULT_WORKDIR=D:\PMT\DEV\HSUniv"

set "AGENT_ROOT=%~dp0"
if "%AGENT_ROOT:~-1%"=="\" set "AGENT_ROOT=%AGENT_ROOT:~0,-1%"

set "HERMES_EXE="
if exist "%AGENT_ROOT%\.venv\Scripts\hermes.exe" set "HERMES_EXE=%AGENT_ROOT%\.venv\Scripts\hermes.exe"
if not defined HERMES_EXE if exist "%AGENT_ROOT%\venv\Scripts\hermes.exe" set "HERMES_EXE=%AGENT_ROOT%\venv\Scripts\hermes.exe"
if not defined HERMES_EXE goto :err_no_hermes

REM Put venv Scripts first so child tools see the same hermes/python.
set "PATH=%~dp0.venv\Scripts;%~dp0venv\Scripts;%PATH%"

REM Default Hermes home on this machine if unset (profiles / config / plugins).
if not defined HERMES_HOME if defined LOCALAPPDATA (
  if exist "%LOCALAPPDATA%\hermes\config.yaml" set "HERMES_HOME=%LOCALAPPDATA%\hermes"
)

REM Resolve initial working directory.
set "HERMES_INIT_CWD="
if defined HERMES_WORKDIR (
  set "HERMES_INIT_CWD=%HERMES_WORKDIR%"
) else if defined HERMES_HOME if exist "%HERMES_HOME%\workdir" (
  set /p HERMES_INIT_CWD=<"%HERMES_HOME%\workdir"
) else if exist "%AGENT_ROOT%\hermes.workdir" (
  set /p HERMES_INIT_CWD=<"%AGENT_ROOT%\hermes.workdir"
) else if defined HERMES_DEFAULT_WORKDIR (
  set "HERMES_INIT_CWD=%HERMES_DEFAULT_WORKDIR%"
)

REM Trim quotes/spaces that often appear in one-line path files.
if defined HERMES_INIT_CWD (
  set "HERMES_INIT_CWD=!HERMES_INIT_CWD:"=!"
  for /f "tokens=* delims= " %%A in ("!HERMES_INIT_CWD!") do set "HERMES_INIT_CWD=%%A"
)

if defined HERMES_INIT_CWD if not "!HERMES_INIT_CWD!"=="" (
  if not exist "!HERMES_INIT_CWD!" goto :err_workdir_missing
  cd /d "!HERMES_INIT_CWD!" 2>nul || goto :err_workdir_cd
  echo [workdir] !CD!
)

"%HERMES_EXE%" %*
endlocal & exit /b %ERRORLEVEL%

:err_no_hermes
echo [error] hermes.exe not found.
echo   Expected: %AGENT_ROOT%\.venv\Scripts\hermes.exe
echo   Run:  cd /d "%AGENT_ROOT%" ^& uv sync
endlocal & exit /b 1

:err_workdir_missing
echo [error] Initial workdir not found:
echo   !HERMES_INIT_CWD!
echo Set HERMES_WORKDIR, or edit %%HERMES_HOME%%\workdir / hermes.workdir
endlocal & exit /b 1

:err_workdir_cd
echo [error] Cannot cd to workdir: !HERMES_INIT_CWD!
endlocal & exit /b 1
