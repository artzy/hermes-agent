@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM Restart Hermes Cursor sidecar with CURSOR_API_KEY from Hermes home.
REM Endpoint: http://127.0.0.1:2389/v1

set "AGENT_ROOT=%~dp0"
if "%AGENT_ROOT:~-1%"=="\" set "AGENT_ROOT=%AGENT_ROOT:~0,-1%"

set "PROXY_ROOT=%AGENT_ROOT%\..\hermes-cursor-provider"
for %%I in ("%PROXY_ROOT%") do set "PROXY_ROOT=%%~fI"

if not exist "%PROXY_ROOT%\hermes_cursor_proxy\__main__.py" (
  echo [error] hermes-cursor-provider not found:
  echo   %PROXY_ROOT%
  exit /b 1
)

if not defined HERMES_HOME if defined LOCALAPPDATA (
  if exist "%LOCALAPPDATA%\hermes\config.yaml" set "HERMES_HOME=%LOCALAPPDATA%\hermes"
)

REM Kill any existing hermes_cursor_proxy (avoid stale process without API key).
powershell -NoProfile -Command ^
  "Get-CimInstance Win32_Process -Filter \"Name='python.exe'\" | Where-Object { $_.CommandLine -match 'hermes_cursor_proxy' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }; Start-Sleep -Seconds 1" >nul 2>&1

REM Refresh PATH for agent CLI.
for /f "usebackq delims=" %%P in (`powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')"`) do set "PATH=%%P"

set "PYTHON_EXE="
if exist "%PROXY_ROOT%\.venv\Scripts\python.exe" set "PYTHON_EXE=%PROXY_ROOT%\.venv\Scripts\python.exe"
if not defined PYTHON_EXE if exist "%PROXY_ROOT%\venv\Scripts\python.exe" set "PYTHON_EXE=%PROXY_ROOT%\venv\Scripts\python.exe"
if not defined PYTHON_EXE set "PYTHON_EXE=python"

REM Prefer real Hermes home .env (where CURSOR_API_KEY usually lives).
call :load_env_key CURSOR_API_KEY
call :load_env_key HERMES_CURSOR_PROXY_HOST
call :load_env_key HERMES_CURSOR_PROXY_PORT
call :load_env_key HERMES_CURSOR_MODE

if not defined HERMES_CURSOR_MODE set "HERMES_CURSOR_MODE=agent"
if defined HERMES_CURSOR_PROXY_HOST (set "_HOST=%HERMES_CURSOR_PROXY_HOST%") else (set "_HOST=127.0.0.1")
if defined HERMES_CURSOR_PROXY_PORT (set "_PORT=%HERMES_CURSOR_PROXY_PORT%") else (set "_PORT=2389")

if defined CURSOR_API_KEY (
  echo [ok] CURSOR_API_KEY loaded from Hermes .env
) else (
  echo [warn] CURSOR_API_KEY missing — run agent login or set it in:
  if defined HERMES_HOME (echo   %HERMES_HOME%\.env) else (echo   %%LOCALAPPDATA%%\hermes\.env)
)

echo Starting sidecar: http://%_HOST%:%_PORT%/v1  mode=%HERMES_CURSOR_MODE%
cd /d "%PROXY_ROOT%" || exit /b 1
start "hermes-cursor-proxy" /MIN "%PYTHON_EXE%" -m hermes_cursor_proxy --host %_HOST% --port %_PORT%

REM Wait briefly and print health.
powershell -NoProfile -Command ^
  "Start-Sleep -Seconds 2; try { $h = Invoke-RestMethod 'http://%_HOST%:%_PORT%/health' -TimeoutSec 5; Write-Host ('[ok] health has_cursor_api_key=' + $h.has_cursor_api_key + ' mode=' + $h.cursor_mode) } catch { Write-Host '[warn] health check failed — sidecar may still be starting' }"

exit /b 0

:load_env_key
if defined %~1 goto :eof
set "_KEY=%~1"
set "_ENV_FILE="
if defined HERMES_HOME if exist "%HERMES_HOME%\.env" set "_ENV_FILE=%HERMES_HOME%\.env"
if not defined _ENV_FILE if exist "%LOCALAPPDATA%\hermes\.env" set "_ENV_FILE=%LOCALAPPDATA%\hermes\.env"
if not defined _ENV_FILE if exist "%USERPROFILE%\.hermes\.env" set "_ENV_FILE=%USERPROFILE%\.hermes\.env"
if not defined _ENV_FILE if exist "%AGENT_ROOT%\.env" set "_ENV_FILE=%AGENT_ROOT%\.env"
if not defined _ENV_FILE goto :eof
for /f "usebackq eol=# tokens=1,* delims==" %%A in ("%_ENV_FILE%") do (
  if /I "%%A"=="!_KEY!" (
    set "%_KEY%=%%B"
    goto :eof
  )
)
goto :eof