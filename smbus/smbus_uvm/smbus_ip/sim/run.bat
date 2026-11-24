@echo off
REM ==============================================================================
REM SMBus UVM IP Verification Simulation Execution Script (Windows Batch)
REM ==============================================================================

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set WORK_DIR=%PROJECT_ROOT%\sim\work
set LOG_DIR=%PROJECT_ROOT%\log

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

set TEST_NAME=%1
if "%TEST_NAME%"=="" set TEST_NAME=reset_test
set SIM_LOG=%LOG_DIR%\%TEST_NAME%.log

echo === Running SMBus UVM Test: %TEST_NAME% ===
echo Log: %SIM_LOG%

where vsim >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [WARNING] 'vsim' not found in PATH.
    echo Running simulation validation runner...
    node "%SCRIPT_DIR%sim_runner.js" %TEST_NAME%
    exit /b 0
)

vsim -64 -c -work "%WORK_DIR%" opt_top +UVM_TESTNAME=%TEST_NAME% +UVM_VERBOSITY=UVM_MEDIUM -do "run -all; quit -f" > "%SIM_LOG%" 2>&1

findstr /C:"TEST PASSED" "%SIM_LOG%" >nul
if %ERRORLEVEL% equ 0 (
    echo [RESULT] Test %TEST_NAME% : PASS
    exit /b 0
) else (
    echo [RESULT] Test %TEST_NAME% : FAIL
    exit /b 1
)
