@echo off
setlocal EnableExtensions

REM Hermes CLI launcher (Windows)
REM Usage: hermes.bat [args...]
REM Example: hermes.bat --version
REM          hermes.bat cursor mode
REM          hermes.bat -z "hello"

set "AGENT_ROOT=%~dp0"
if "%AGENT_ROOT:~-1%"=="\" set "AGENT_ROOT=%AGENT_ROOT:~0,-1%"

set "HERMES_EXE="
if exist "%AGENT_ROOT%\.venv\Scripts\hermes.exe" set "HERMES_EXE=%AGENT_ROOT%\.venv\Scripts\hermes.exe"
if not defined HERMES_EXE if exist "%AGENT_ROOT%\venv\Scripts\hermes.exe" set "HERMES_EXE=%AGENT_ROOT%\venv\Scripts\hermes.exe"

if not defined HERMES_EXE (
  echo [error] hermes.exe not found.
  echo   Expected: %AGENT_ROOT%\.venv\Scripts\hermes.exe
  echo   Run:  cd /d "%AGENT_ROOT%" ^& uv sync
  exit /b 1
)

REM Put venv Scripts first so child tools see the same hermes/python.
set "PATH=%~dp0.venv\Scripts;%~dp0venv\Scripts;%PATH%"

REM Default Hermes home on this machine if unset (profiles / config / plugins).
if not defined HERMES_HOME if defined LOCALAPPDATA (
  if exist "%LOCALAPPDATA%\hermes\config.yaml" set "HERMES_HOME=%LOCALAPPDATA%\hermes"
)

"%HERMES_EXE%" %*
exit /b %ERRORLEVEL%