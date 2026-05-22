@echo off
REM FPGA Build and Deployment Script
REM Builds Vivado project and programs the FPGA

setlocal enabledelayedexpansion

set PROJECT_DIR=%~dp0..\verilog
set BUILD_DIR=%PROJECT_DIR%\build
set SCRIPTS_DIR=%PROJECT_DIR%\scripts

echo.
echo ============================================================
echo FPGA Build and Deployment Script
echo ============================================================
echo Project: %PROJECT_DIR%
echo Build Dir: %BUILD_DIR%
echo.

cd /d "%PROJECT_DIR%" || (
    echo ERROR: Could not change to project directory
    exit /b 1
)

REM Check if Vivado is installed
where vivado >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Vivado not found in PATH
    echo Please ensure Vivado is installed and added to system PATH
    exit /b 1
)

echo [1] Vivado version:
vivado -version
echo.

echo [2] Starting synthesis and implementation...
REM Run Vivado in TCL mode to build the project
vivado -mode batch -source "%SCRIPTS_DIR%\build_tools\build.tcl" -notrace

if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Build failed
    exit /b 1
)

echo.
echo [3] Build successful!
echo.
echo [4] FPGA is ready to program. Follow these steps:
echo    1. Connect FPGA to USB
echo    2. Slide SW[0] RIGHT to enable oscillator
echo    3. Run the PowerShell collection script:
echo       PowerShell -File "%~dp0collect_random_data.ps1"
echo.

pause
