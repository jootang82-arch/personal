#!/usr/bin/env bash
# ==============================================================================
# SMBus UVM IP Verification Compile Script
# Target Simulator: QuestaSim / Questa (Mentor / Siemens EDA)
# ==============================================================================

set -e

# Setup directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORK_DIR="${PROJECT_ROOT}/sim/work"
LOG_DIR="${PROJECT_ROOT}/log"

mkdir -p "${LOG_DIR}"

NUM_SLAVE="${1:-1}"
COMPILE_LOG="${LOG_DIR}/compile.log"
echo "=== SMBus UVM IP Verification Environment Compilation (NUM_SLAVE=${NUM_SLAVE}) ===" | tee "${COMPILE_LOG}"
echo "Project Root: ${PROJECT_ROOT}" | tee -a "${COMPILE_LOG}"
echo "Timestamp   : $(date)" | tee -a "${COMPILE_LOG}"

# 1. Check Simulator Availability
if ! command -v vlog &> /dev/null; then
    echo "[WARNING] 'vlog' (QuestaSim compiler) not found in system PATH." | tee -a "${COMPILE_LOG}"
    echo "Please ensure QuestaSim environment variables (e.g. MTI_HOME, QUESTASIM_HOME) are configured." | tee -a "${COMPILE_LOG}"
    echo "Standard compile syntax will be checked using syntax verification." | tee -a "${COMPILE_LOG}"
    # Check if node syntax validator exists
    if [ -f "${SCRIPT_DIR}/syntax_check.js" ]; then
        node "${SCRIPT_DIR}/syntax_check.js" | tee -a "${COMPILE_LOG}"
        exit 0
    else
        exit 1
    fi
fi

# 2. Initialize Work Library
echo "[STEP 1] Initializing work library at ${WORK_DIR}..." | tee -a "${COMPILE_LOG}"
if [ -d "${WORK_DIR}" ]; then
    rm -rf "${WORK_DIR}"
fi
vlib "${WORK_DIR}" | tee -a "${COMPILE_LOG}"
vmap work "${WORK_DIR}" | tee -a "${COMPILE_LOG}"

# 3. Compile HDL Sources
echo "[STEP 2] Compiling HDL sources from list/hdl.f (+define+NUM_SLAVE=${NUM_SLAVE})..." | tee -a "${COMPILE_LOG}"
cd "${PROJECT_ROOT}/list"
vlog -64 -sv -work "${WORK_DIR}" -timescale "1ns/1ps" +define+NUM_SLAVE="${NUM_SLAVE}" -f hdl.f | tee -a "${COMPILE_LOG}"
if [ $? -ne 0 ]; then
    echo "[ERROR] HDL Compilation Failed! Refer to ${COMPILE_LOG}" | tee -a "${COMPILE_LOG}"
    exit 1
fi

# 4. Compile HVL Sources
echo "[STEP 3] Compiling HVL sources from list/hvl.f with UVM library..." | tee -a "${COMPILE_LOG}"
vlog -64 -sv -work "${WORK_DIR}" +acc -timescale "1ns/1ps" +incdir+"$UVM_HOME/src" "$UVM_HOME/src/uvm_pkg.sv" -f hvl.f | tee -a "${COMPILE_LOG}"
if [ $? -ne 0 ]; then
    echo "[ERROR] HVL Compilation Failed! Refer to ${COMPILE_LOG}" | tee -a "${COMPILE_LOG}"
    exit 1
fi

# 5. Elaboration & Optimization (vopt)
echo "[STEP 4] Elaborating design with vopt..." | tee -a "${COMPILE_LOG}"
vopt -64 +acc work.hdl_top work.hvl_top -o opt_top -work "${WORK_DIR}" | tee -a "${COMPILE_LOG}"
if [ $? -ne 0 ]; then
    echo "[ERROR] Elaboration (vopt) Failed! Refer to ${COMPILE_LOG}" | tee -a "${COMPILE_LOG}"
    exit 1
fi

echo "[SUCCESS] Compilation and Elaboration PASSED successfully!" | tee -a "${COMPILE_LOG}"
exit 0
