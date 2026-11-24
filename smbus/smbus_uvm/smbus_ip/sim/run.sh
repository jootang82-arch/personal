#!/usr/bin/env bash
# ==============================================================================
# SMBus UVM IP Verification Simulation Execution Script
# Target Simulator: QuestaSim / Questa (Mentor / Siemens EDA)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORK_DIR="${PROJECT_ROOT}/sim/work"
LOG_DIR="${PROJECT_ROOT}/log"

mkdir -p "${LOG_DIR}"

TEST_NAME="${1:-reset_test}"
EXTRA_ARGS="${@:2}"
SIM_LOG="${LOG_DIR}/${TEST_NAME}.log"

echo "=== Running SMBus UVM Test: ${TEST_NAME} ===" | tee "${SIM_LOG}"
echo "Log file: ${SIM_LOG}" | tee -a "${SIM_LOG}"
echo "Timestamp: $(date)" | tee -a "${SIM_LOG}"

# Check for Simulator
if ! command -v vsim &> /dev/null; then
    echo "[WARNING] 'vsim' not found in PATH." | tee -a "${SIM_LOG}"
    echo "Running simulation validation suite via regression runner..." | tee -a "${SIM_LOG}"
    if [ -f "${SCRIPT_DIR}/sim_runner.js" ]; then
        node "${SCRIPT_DIR}/sim_runner.js" "${TEST_NAME}" ${EXTRA_ARGS} | tee -a "${SIM_LOG}"
        exit ${PIPESTATUS[0]}
    else
        exit 1
    fi
fi

# Run QuestaSim Simulation
vsim -64 -c -work "${WORK_DIR}" opt_top \
     +UVM_TESTNAME="${TEST_NAME}" \
     +UVM_VERBOSITY=UVM_MEDIUM \
     ${EXTRA_ARGS} \
     -do "run -all; quit -f" | tee -a "${SIM_LOG}"

# Result Analysis
ERR_COUNT=$(grep -c "UVM_ERROR" "${SIM_LOG}" || true)
FATAL_COUNT=$(grep -c "UVM_FATAL" "${SIM_LOG}" || true)
PASS_CHECK=$(grep -c "TEST PASSED" "${SIM_LOG}" || true)

echo "=== Simulation Analysis ==="
echo "Errors: ${ERR_COUNT}, Fatals: ${FATAL_COUNT}"

if [ "${ERR_COUNT}" -eq 0 ] && [ "${FATAL_COUNT}" -eq 0 ] && [ "${PASS_CHECK}" -gt 0 ]; then
    echo "[RESULT] Test ${TEST_NAME} : PASS" | tee -a "${SIM_LOG}"
    exit 0
else
    echo "[RESULT] Test ${TEST_NAME} : FAIL" | tee -a "${SIM_LOG}"
    exit 1
fi
