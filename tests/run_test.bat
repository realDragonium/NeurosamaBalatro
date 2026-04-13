@echo off
REM Sync mod to Balatro and start the test harness
REM Usage: run_test.bat [scenario_name] [--verbose]
REM
REM After running this, launch Balatro through Steam.

set "PROJECT_DIR=%~dp0.."
set "MOD_DIR=%APPDATA%\Balatro\Mods\NeurosamaBalatro"

echo === NeurosamaBalatro Test Runner ===

REM Step 1: Sync mod files
echo [1/2] Syncing mod to %MOD_DIR%...
if exist "%MOD_DIR%" rmdir /s /q "%MOD_DIR%"
xcopy "%PROJECT_DIR%" "%MOD_DIR%\" /e /i /q /y >nul
if exist "%MOD_DIR%\.claude" rmdir /s /q "%MOD_DIR%\.claude"
if exist "%MOD_DIR%\.git" rmdir /s /q "%MOD_DIR%\.git"
if exist "%MOD_DIR%\tests" rmdir /s /q "%MOD_DIR%\tests"
echo       Mod synced.

REM Step 2: Start test harness
set "SCENARIO=%~1"
if "%SCENARIO%"=="" set "SCENARIO=startup"

echo [2/2] Starting test harness (scenario: %SCENARIO%)...
echo       Launch Balatro through Steam now.
echo.

python "%~dp0test_harness.py" --scenario %SCENARIO% %2 %3 %4
