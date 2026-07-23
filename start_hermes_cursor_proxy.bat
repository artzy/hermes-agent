@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Hermes Cursor OpenAI-compat sidecar launcher (from hermes-agent)
REM Default: http://127.0.0.1:2389/v1

set "AGENT_ROOT=%~dp0"
if "%AGENT_ROOT:~-1%"=="\" set "AGENT_ROOT=%AGENT_ROOT:~0,-1%"

REM Sidecar package lives in the sibling repo.
set "PROXY_ROOT=%AGENT_ROOT%\..\hermes-cursor-provider"
for %%I in ("%PROXY_ROOT%") do set "PROXY_ROOT=%%~fI"

if not exist "%PROXY_ROOT%\hermes_cursor_proxy\__main__.py" (
  echo [error] hermes-cursor-provider not found at:
  echo   %PROXY_ROOT%
  echo Clone/install it next to hermes-agent, or edit PROXY_ROOT in this bat.
  exit /b 1
)

cd /d "%PROXY_ROOT%" || (
  echo [error] Cannot cd to proxy root: %PROXY_ROOT%
  exit /b 1
)

REM Refresh PATH so Cursor Agent CLI (agent) is visible in this session.
for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')"`) do set "PATH=%%P"

REM Prefer a local venv in the proxy repo if present.
set "PYTHON_EXE="
if exist "%PROXY_ROOT%\.venv\Scripts\python.exe" set "PYTHON_EXE=%PROXY_ROOT%\.venv\Scripts\python.exe"
if not defined PYTHON_EXE if exist "%PROXY_ROOT%\venv\Scripts\python.exe" set "PYTHON_EXE=%PROXY_ROOT%\venv\Scripts\python.exe"
if not defined PYTHON_EXE set "PYTHON_EXE=python"

REM Load CURSOR_API_KEY / proxy bind vars from Hermes .env if unset.
call :load_env_key CURSOR_API_KEY
call :load_env_key HERMES_CURSOR_PROXY_HOST
call :load_env_key HERMES_CURSOR_PROXY_PORT

if not defined CURSOR_API_KEY (
  echo [note] CURSOR_API_KEY unset - proxy will try cursor-sdk / agent login session.
)

echo Starting hermes-cursor-proxy from:
echo   %PROXY_ROOT%
echo Python:
echo   %PYTHON_EXE%
if defined HERMES_CURSOR_PROXY_HOST (set "_HOST=%HERMES_CURSOR_PROXY_HOST%") else (set "_HOST=127.0.0.1")
if defined HERMES_CURSOR_PROXY_PORT (set "_PORT=%HERMES_CURSOR_PROXY_PORT%") else (set "_PORT=2389")
echo Endpoint:
echo   http://%_HOST%:%_PORT%/v1
echo.

"%PYTHON_EXE%" -m hermes_cursor_proxy %*
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" (
  echo.
  echo [error] hermes_cursor_proxy exited with code %RC%
  echo Tip: cd /d "%PROXY_ROOT%" ^& pip install -e ".[sdk]"
  echo      and ensure agent is on PATH.
  exit /b %RC%
)
exit /b 0

REM ---------------------------------------------------------------------------
:load_env_key
if defined %~1 goto :eof

set "_KEY=%~1"
set "_ENV_FILE="

REM Prefer this checkout's .env, then profile / user Hermes homes.
if exist "%AGENT_ROOT%\.env" set "_ENV_FILE=%AGENT_ROOT%\.env"
if not defined _ENV_FILE if defined HERMES_HOME if exist "%HERMES_HOME%\.env" set "_ENV_FILE=%HERMES_HOME%\.env"
if not defined _ENV_FILE if exist "%USERPROFILE%\.hermes\.env" set "_ENV_FILE=%USERPROFILE%\.hermes\.env"
if not defined _ENV_FILE if exist "%LOCALAPPDATA%\hermes\.env" set "_ENV_FILE=%LOCALAPPDATA%\hermes\.env"
if not defined _ENV_FILE goto :eof

for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%_ENV_FILE%") do (
  if /I "%%A"=="!_KEY!" (
    set "%_KEY%=%%B"
    goto :eof
  )
)
goto :eof