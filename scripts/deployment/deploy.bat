@echo off
REM Simple batch file wrapper for deploy.ps1
REM This allows double-clicking to deploy

echo.
echo ========================================
echo   FPGA Deployment Script
echo ========================================
echo.

powershell.exe -ExecutionPolicy Bypass -File "%~dp0deploy.ps1"

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Deployment completed successfully!
    echo.
) else (
    echo.
    echo Deployment failed! Check errors above.
    echo.
)

pause
