@echo off
REM ==============================================================================
REM SMBus UVM IP Verification Compile Script (Windows Batch)
REM Target Simulator: QuestaSim / ModelSim
REM ==============================================================================

set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set WORK_DIR=%PROJECT_ROOT%\sim\work
set LOG_DIR=%PROJECT_ROOT%\log

if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"
set NUM_SLAVE=%1
if "%NUM_SLAVE%"=="" set NUM_SLAVE=1
set COMPILE_LOG=%LOG_DIR%\compile.log

echo === SMBus UVM IP Verification Environment Compilation (NUM_SLAVE=%NUM_SLAVE%) === > "%COMPILE_LOG%"
echo Timestamp: %DATE% %TIME% >> "%COMPILE_LOG%"

where vlog >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [WARNING] 'vlog' (QuestaSim compiler) not found in system PATH.
    echo Running syntax and rule verification...
    node "%SCRIPT_DIR%syntax_check.js"
    node "%SCRIPT_DIR%check_this_rule.js"
    exit /b 0
)

echo [STEP 1] Initializing work library at %WORK_DIR%...
if exist "%WORK_DIR%" rmdir /s /q "%WORK_DIR%"
vlib "%WORK_DIR%" >> "%COMPILE_LOG%" 2>&1
vmap work "%WORK_DIR%" >> "%COMPILE_LOG%" 2>&1

echo [STEP 2] Compiling HDL sources from list/hdl.f (+define+NUM_SLAVE=%NUM_SLAVE%)...
cd /d "%PROJECT_ROOT%\list"
vlog -64 -sv -work "%WORK_DIR%" -timescale "1ns/1ps" +define+NUM_SLAVE=%NUM_SLAVE% -f hdl.f >> "%COMPILE_LOG%" 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] HDL Compilation Failed!
    exit /b 1
)

echo [STEP 3] Compiling HVL sources from list/hvl.f...
vlog -64 -sv -work "%WORK_DIR%" +acc -timescale "1ns/1ps" -f hvl.f >> "%COMPILE_LOG%" 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] HVL Compilation Failed!
    exit /b 1
)

echo [STEP 4] Elaborating design with vopt...
vopt -64 +acc work.hdl_top work.hvl_top -o opt_top -work "%WORK_DIR%" >> "%COMPILE_LOG%" 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] Elaboration Failed!
    exit /b 1
)

echo [SUCCESS] Compilation and Elaboration Completed!
exit /b 0
