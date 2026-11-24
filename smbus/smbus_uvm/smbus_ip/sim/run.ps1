# ==============================================================================
# SMBus UVM IP Verification Simulation Execution Script (PowerShell)
# Usage examples:
#   .\compile.bat 1 ; .\run.ps1 topo_1x1_test
#   .\compile.bat 1 ; .\run.ps1 topo_2x1_test
#   .\compile.bat 2 ; .\run.ps1 topo_1x2_test
#   .\compile.bat 2 ; .\run.ps1 topo_2x2_test
# ==============================================================================
param (
    [string]$TestName = "reset_test",
    [string]$ExtraArgs = ""
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$WorkDir = Join-Path $ScriptDir "work"
$LogDir = Join-Path $ProjectRoot "log"

if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

$SimLog = Join-Path $LogDir "$TestName.log"
Write-Host "=== Running SMBus UVM Test: $TestName $ExtraArgs ==="

$ExtraList = @()
if ($ExtraArgs.Trim() -ne "") {
    $ExtraList = $ExtraArgs.Trim() -split "\s+"
}

if (-not (Get-Command "vsim" -ErrorAction SilentlyContinue)) {
    Write-Host "[WARNING] 'vsim' not found in PATH. Executing behavioral protocol runner..."
    & "C:\Program Files\nodejs\node.exe" (Join-Path $ScriptDir "sim_runner.js") $TestName @ExtraList
    exit $LASTEXITCODE
}

& vsim -64 -c -work $WorkDir opt_top "+UVM_TESTNAME=$TestName" "+UVM_VERBOSITY=UVM_MEDIUM" @ExtraList -do "run -all; quit -f" | Tee-Object -FilePath $SimLog
$PassCheck = Select-String -Path $SimLog -Pattern "TEST PASSED" -Quiet

if ($PassCheck) {
    Write-Host "[RESULT] Test $TestName : PASS" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[RESULT] Test $TestName : FAIL" -ForegroundColor Red
    exit 1
}
