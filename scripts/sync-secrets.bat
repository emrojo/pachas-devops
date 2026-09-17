@echo off
setlocal

REM ==============================================================================
REM Pachas DevOps - Sync Secrets Batch Wrapper
REM Executes sync-secrets.ps1 with ExecutionPolicy Bypass
REM Usage:
REM   sync-secrets.bat [EnvFile] [Mode: Individual|Single] [-Environment name] [-Repo owner/repo]
REM ==============================================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync-secrets.ps1" %*
set EXITCODE=%ERRORLEVEL%

REM If launched by double-clicking in File Explorer, pause before closing
echo %cmdcmdline% | findstr /i /c:"%~f0" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo.
    pause
)

exit /b %EXITCODE%
