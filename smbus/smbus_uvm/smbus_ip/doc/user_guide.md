# SMBus UVM IP Verification Environment User Guide

## 1. 개요 (Introduction)
본 문서는 `smbus_uvm` 검증 환경의 디렉터리 구성, 컴파일 방법, 개별 테스트 및 회귀 테스트(Regression) 시뮬레이션 실행 방법, 결과 분석 가이드를 제공합니다.

---

## 2. 전체 디렉터리 및 파일 구조

```text
smbus_uvm/
│
├── smbus_ip/                           # IP 전용 검증 환경 ({ip})
│   ├── hvl/
│   │   ├── env_ip/
│   │   │   ├── smbus_ip_scoreboard.sv  # IP Scoreboard (Actual vs Reference 비교)
│   │   │   ├── smbus_ip_env.sv         # IP Verification Environment
│   │   │   └── smbus_ip_env.pkg.sv     # IP Environment Package
│   │   ├── seq_ip/
│   │   │   ├── smbus_ip_base_sequence.sv # IP Base Sequence (Static Sequencer 선언)
│   │   │   └── smbus_ip_seq.pkg.sv     # IP Sequence Package
│   │   └── top/
│   │       └── hvl_top.sv              # HVL Top Module (run_test 호출)
│   │
│   ├── hdl/
│   │   ├── smbus_ip_slave_model.sv     # 검증용 임시 DUT SMBus Slave RTL 모델
│   │   └── hdl_top.sv                  # HDL Top Module (Clock, Reset, DUT 연결)
│   │
│   ├── list/
│   │   ├── hvl.f                       # HVL Compile File List (VIP + IP 참조)
│   │   └── hdl.f                       # HDL Compile File List (VIP IF + DUT 참조)
│   │
│   ├── misc/
│   │   ├── smbus_ip_types.sv           # Type 및 Enum 정의 Class
│   │   ├── smbus_ip_port.sv            # Parameter 정의 Class
│   │   └── smbus_ip_misc.pkg.sv        # Misc Package
│   │
│   ├── tests/
│   │   ├── tc_base.sv                  # Test Base Class (tc_base)
│   │   ├── tc_reset.sv ~ tc_random.sv  # TC001 ~ TC010
│   │   └── tests.pkg.sv                # Tests Package
│   │
│   ├── sim/
│   │   ├── compile.sh / compile.bat    # 컴파일 스크립트
│   │   ├── run.sh / run.bat / run.ps1  # 시뮬레이션 실행 스크립트
│   │   └── Makefile                    # 빌드/회귀 자동화
│   │
│   ├── log/                            # 테스트별 시뮬레이션 로그
│   └── doc/                            # 검증 문서 (verification_plan, coding_rule, user_guide)
│
└── vip/                                # 재사용 가능한 독립 VIP 영역
    └── smbus/
        ├── hvl/
        │   ├── env/
        │   │   ├── smbus_seq_item.sv     # SMBus Sequence Item Class (smbus_transaction)
        │   │   ├── smbus_pkg.sv          # SMBus VIP Package (IP 비종속)
        │   │   ├── smbus_master_sqr.sv   # Master Sequencer
        │   │   ├── smbus_master_drv.sv   # Master Driver
        │   │   ├── smbus_master_agt.sv   # Master Agent
        │   │   ├── smbus_slave_sqr.sv    # Slave Sequencer
        │   │   ├── smbus_slave_drv.sv    # Slave Driver
        │   │   ├── smbus_slave_agt.sv    # Slave Agent
        │   │   └── smbus_mon.sv          # 공용 Bus Monitor
        │   └── seq/
        │       ├── smbus_base_sequence.sv
        │       ├── smbus_master_sequence.sv
        │       └── smbus_slave_sequence.sv
        └── intf/
            └── smbus.if.sv               # SMBus Physical Interface (Open-Drain, Pull-up)
```

---

## 3. 환경 요구 사항 (Requirements)

- **Simulator**: QuestaSim / ModelSim 2020.x 이상 권장 (VCS, Xcelium 등 표준 IEEE 1800 SystemVerilog 시뮬레이터 지원)
- **UVM Version**: UVM 1.1d, UVM 1.2 또는 IEEE 1800.2
- **Shell**: Bash (Linux) 또는 PowerShell / Command Prompt (Windows)
- **Node.js**: (선택 사항) 로컬 문법/코딩 규칙 자체 검증용 (v16 이상)

---

## 4. 컴파일 및 빌드 (Compilation)

### 4.1 Linux / QuestaSim 환경
```bash
cd smbus_uvm/sim
chmod +x compile.sh run.sh
./compile.sh
```
`compile.sh`는 다음 단계를 수행합니다:
1. `sim/work` 작업 라이브러리 초기화 (`vlib`, `vmap`)
2. `list/hdl.f`를 통한 인터페이스 및 DUT 컴파일 (`vlog`)
3. `list/hvl.f`를 통한 UVM 패키지 및 테스트벤치 컴파일 (`vlog`)
4. 최상위 모듈 Elaboration 및 최적화 (`vopt work.hdl_top work.hvl_top -o opt_top`)
5. 컴파일 결과 `log/compile.log` 저장

### 4.2 Windows 환경
```powershell
cd smbus_uvm/sim
./compile.bat
```

---

## 5. 시뮬레이션 실행 (Running Tests)

### 5.1 개별 테스트 실행
`run.sh` (또는 Windows의 `run.ps1`, `run.bat`)에 테스트 이름을 인자로 전달하여 실행합니다.

```bash
# 기본 리셋 테스트
./sim/run.sh reset_test

# 단일 바이트 쓰기 테스트
./sim/run.sh write_test

# 단일 바이트 읽기 테스트
./sim/run.sh read_test

# 다중 바이트 버스트 쓰기 테스트
./sim/run.sh multi_byte_test

# Repeated START 테스트
./sim/run.sh restart_test

# 랜덤 시드를 지정한 랜덤 트랜잭션 테스트
./sim/run.sh random_test +ntb_random_seed=1234
```

PowerShell 사용 시:
```powershell
powershell -File sim/run.ps1 write_test
```

### 5.2 전체 회귀 테스트 (Regression)
전체 10개 테스트를 연속 실행하고 결과를 수집합니다:

```bash
cd smbus_uvm/sim
make regression
```
또는
```powershell
node sim/sim_runner.js all
```

---

## 6. 검증 결과 및 로그 분석 (Result Analysis)

각 시뮬레이션 실행 후 `log/<test_name>.log`에 상세 로그가 기록됩니다.

### 6.1 정상 PASS 로그 예시 (`log/write_test.log`)
```text
# UVM_INFO ../hvl/top/hvl_top.sv(12) @ 0: uvm_test_top [HVL_TOP] Starting SMBus UVM Testbench execution...
# UVM_INFO ../tests/tc_base.sv(42) @ 0: uvm_test_top [TC_BASE] UVM Elaboration completed. Printing component topology:
# ----------------------------------------------------------------------
# Name                          Type                    Size  Value     
# ----------------------------------------------------------------------
# uvm_test_top                  write_test              -     @336      
#   m_st_env                    smbus_ip_env         -     @345      
#     m_st_smbus_master_agt     smbus_master_agt     -     @352      
#       m_st_sqr                smbus_master_sqr     -     @360      
#       m_st_drv                smbus_master_drv     -     @368      
#     m_st_smbus_slave_agt      smbus_slave_agt      -     @376      
#       m_st_sqr                smbus_slave_sqr      -     @384      
#       m_st_drv                smbus_slave_drv      -     @392      
#     m_st_mon                  smbus_mon            -     @400      
#     m_st_scoreboard           smbus_ip_scoreboard  -     @408      
# ----------------------------------------------------------------------
# UVM_INFO ../hvl/seq_ip/smbus_ip_base_sequence.sv(108) @ 100000: ... [SEQ_WRITE] Executing Master Write: Addr=0x2a Reg=0x15 Data=0xa5
# UVM_INFO ../hvl/env/smbus_mon.sv(42) @ 100500: ... [SMBUS_MON] START condition detected
# UVM_INFO ../hvl/env/smbus_mon.sv(115) @ 127500: ... [SMBUS_MON] Collected SMBus Trans: Addr=0x2a RW=WR Len=2 ACK=1 NACK=0 PEC_EN=0 PEC=0x00 Data=[ 0x15 0xa5 ]
# UVM_INFO ../hvl/env_ip/smbus_ip_scoreboard.sv(48) @ 127500: ... [SCOREBOARD] Evaluating Transaction #1: ...
# UVM_INFO ../hvl/env_ip/smbus_ip_scoreboard.sv(78) @ 127500: ... [SCOREBOARD] RefMem update: mem[0x15] = 0xa5
# UVM_INFO ../hvl/env_ip/smbus_ip_scoreboard.sv(110) @ 2000000: ... [SCOREBOARD]
# =======================================================
#                SCOREBOARD SUMMARY REPORT               
# =======================================================
#   Total Transactions Checked : 1
#   Matches                    : 2
#   Mismatches                 : 0
#   Status                     : PASSED
# =======================================================
# UVM_INFO ../tests/tc_base.sv(60) @ 2000000: uvm_test_top [TC_BASE]
# =======================================================
#                     TEST SUMMARY REPORT                
# =======================================================
#   Test Name    : write_test
#   Errors       : 0
#   Fatals       : 0
#   Result       : TEST PASSED
# =======================================================
# --- UVM Report catcher Summary ---
# ** Report counts by severity
# UVM_INFO :   10
# UVM_WARNING :    0
# UVM_ERROR :    0
# UVM_FATAL :    0
```

### 6.2 판정 기준
1. `UVM_ERROR` = 0
2. `UVM_FATAL` = 0
3. `Scoreboard Mismatches` = 0
4. `Result : TEST PASSED` 출력 확인
