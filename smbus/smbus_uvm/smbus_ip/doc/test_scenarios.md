# SMBus UVM 테스트케이스별 검증 시나리오, Waveform 및 결과 명세서

본 문서는 **Single Master/Slave VIP** + **`smbus_ip_env #(NUM_MASTER)`** + **`hdl_top` (`NUM_SLAVE` define 기반 DUT Slave Model)** 구조에서 수행되는 전체 테스트케이스(`TC001`~`TC010` 및 **`1:1`, `2:1`, `1:2`, `2:2`** 토폴로지 테스트)의 시나리오, Waveform, Scoreboard 검증 기준 및 테스트 결과를 정리합니다.

---

## 0. 검증 환경 아키텍처 및 Scoreboard 확인 기준

### 0.1 아키텍처 구조
```text
                        +-------------------------------------------------------------------+
                        |                   tc_base_param #(NUM_MASTER)                     |
                        +-------------------------------------------------------------------+
                                                          |
                        +-------------------------------------------------------------------+
                        |                  smbus_ip_env #(NUM_MASTER)                       |
                        |                                                                   |
                        |  +------------------------+     +------------------------+        |
                        |  | m_ast_master_agt[0]    | ... | m_ast_master_agt[N-1]  |        |
                        |  | (Single Master VIP)    |     | (Single Master VIP)    |        |
                        |  +-----------+------------+     +-----------+------------+        |
                        |              | master_vif_0                 | master_vif_(N-1)    |
                        |  +-----------v------------------------------v------------+        |
                        |  |            smbus_mon (u_mon_if 관찰)                   |        |
                        |  +---------------------------+---------------------------+        |
                        |                              | analysis_port                      |
                        |  +---------------------------v---------------------------+        |
                        |  |         smbus_ip_scoreboard (Multi-Slave RefMem)      |        |
                        |  +-------------------------------------------------------+        |
                        +-------------------------------------------------------------------+
                                                          |
  ================= hdl_top (Shared Physical Open-Drain Bus: tri1 scl, tri1 sda) =================
    - Single VIP Interfaces : gen_master_if[0..MAX_MASTER_IF-1].u_smbus_if (inout scl, sda)
    - Monitor VIP Interface : u_mon_if (inout scl, sda)
    - HDL DUT Slave Models  : gen_slave_dut[0..`NUM_SLAVE-1].u_dut (smbus_ip_slave_model)
        * DUT_S0: SLAVE_ADDR = 7'h2A  (`NUM_SLAVE >= 1)
        * DUT_S1: SLAVE_ADDR = 7'h2B  (`NUM_SLAVE >= 2)
  ================================================================================================
```

- **VIP (`vip/smbus/`)**: Single Master / Single Slave 전용 (`smbus_if`도 단일 엔드포인트 `inout scl, sda` 오픈드레인 인터페이스)
- **Master 개수 제어 (`smbus_ip_env`)**: `parameter int NUM_MASTER = 1` (1 또는 2) → 파라미터 수만큼 독립적인 Single Master VIP Agent 생성
- **Slave(DUT) 개수 제어 (`hdl_top`)**: `` `define NUM_SLAVE `` (`+define+NUM_SLAVE=1` 또는 `2`) → `generate` 블록으로 `smbus_ip_slave_model` DUT 인스턴스 생성 (`7'h2A + s`), `uvm_config_db`의 `"num_slaves"`로 HVL에 자동 전달
- **초기 메모리 및 타이밍**:
  - 각 DUT Slave 모델 및 Scoreboard Reference Memory(`m_an_slave_ref_mem[s][0:255]`) 초기값 = `8'hA0 + offset`
  - `SCL` 반주기 = `250ns` (주기 `500ns`), `START(S)`: `SCL=H, SDA 1→0`, `STOP(P)`: `SCL=H, SDA 0→1`, `Repeated START(Sr)`: `STOP` 없이 `SCL=H, SDA 1→0`

### 0.2 Scoreboard (`smbus_ip_scoreboard`) 확인 사항
1. **주소 매칭 및 ACK/NACK 판정**: `m_an_slave_addrs[0..`NUM_SLAVE-1]` 중 일치 주소면 `ACK(0)` 필수, 미일치 주소(`0x55` 등)면 `NACK(1)` 필수
2. **슬레이브별 Write Reference Memory & Pointer 갱신**: `Len>=2` 시 `data[0]`을 시작 주소로 하여 `m_an_slave_ref_mem[s]` 기록 및 포인터 증가, `Len==1` 시 포인터 설정
3. **슬레이브별 Read 데이터 무결성 비교**: `m_an_slave_ref_mem[s][ptr + i]`와 실제 버스 Read 바이트 일치 여부 확인 (불일치 시 `READ_DATA_MISMATCH` `UVM_ERROR`)
4. **프로토콜 무결성**: `START=1` 확인, `PEC` 활성화 시 CRC-8 검증, 슬레이브별 트랜잭션 카운트(`m_an_slave_trans_cnt[s]`) 집계
5. **최종 PASS 기준**: `Mismatches == 0`, `UVM_ERROR == 0`, `UVM_FATAL == 0`, 활성 Master·Slave 활동 카운트 모두 `> 0`, `TEST PASSED`

---

## 전체 테스트케이스 요약 및 실행 결과

| TC ID | Test Name | `NUM_MASTER` (Env Param) | `` `NUM_SLAVE `` (HDL Define) | 토폴로지 | Total Trans | Matches | Mismatches | 결과 |
|---|---|---:|---:|---|---:|---:|---:|---|
| **TC001** | `reset_test` | 1 | 1 | `1 : 1` | 0 | 0 | 0 | **PASS** |
| **TC002** | `idle_test` | 1 | 1 | `1 : 1` | 0 | 0 | 0 | **PASS** |
| **TC003** | `start_stop_test` | 1 | 1 | `1 : 1` | 1 | 2 | 0 | **PASS** |
| **TC004** | `write_test` | 1 | 1 | `1 : 1` | 1 | 2 | 0 | **PASS** |
| **TC005** | `read_test` | 1 | 1 | `1 : 1` | 2 | 4 | 0 | **PASS** |
| **TC006** | `ack_test` | 1 | 1 | `1 : 1` | 1 | 2 | 0 | **PASS** |
| **TC007** | `nack_test` | 1 | 1 | `1 : 1` | 1 | 1 | 0 | **PASS** |
| **TC008** | `multi_byte_test` | 1 | 1 | `1 : 1` | 1 | 2 | 0 | **PASS** |
| **TC009** | `restart_test` | 1 | 1 | `1 : 1` | 2 | 4 | 0 | **PASS** |
| **TC010** | `random_test` | 1 | 1 | `1 : 1` | 8 | 20 | 0 | **PASS** |
| **TC011-1** | `topo_1x1_test` (`topo_m1_test`) | **1** | **1** | **`1 : 1`** | 10 | 21 | 0 | **PASS** |
| **TC011-2** | `topo_2x1_test` (`topo_m2_test`) | **2** | **1** | **`2 : 1`** | 19 | 41 | 0 | **PASS** |
| **TC011-3** | `topo_1x2_test` (`topo_m1_test`) | **1** | **2** | **`1 : 2`** | 19 | 41 | 0 | **PASS** |
| **TC011-4** | `topo_2x2_test` (`topo_m2_test`) | **2** | **2** | **`2 : 2`** | 37 | 81 | 0 | **PASS** |

---

## 개별 테스트케이스 상세 명세 (`TC001` ~ `TC010`)

---

### TC001: `reset_test` (`tc_reset`)

#### 1. 원하는 시나리오 (Master / Slave 개수 포함)
- **구성**: **Master 1개 (`NUM_MASTER=1`, `M0`) : Slave DUT 1개 (`` `NUM_SLAVE=1 ``, `DUT_S0 @ 7'h2A`)**
- **호출 시퀀스**: `smbus_ip_reset_seq`
- **시나리오**: `t = 0~100ns` 동안 `rst_n = 0` 리셋 인가 후 해제(`rst_n = 1`). `M0`와 `DUT_S0` 모두 Open-Drain Release 상태를 유지하며 Pull-up에 의해 `SCL=1, SDA=1` Idle 상태가 안정적으로 유지됨을 확인.

#### 2. 테스트 Waveform
```text
Time(ns)       0         100       300       600       800
               |          |         |         |         |
rst_n          ___________/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
SCL (tri1)     ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾  (Pull-up High)
SDA (tri1)     ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾  (Pull-up High)
M0_if.oe       __________________________________________  (0: Released)
DUT_S0_oe      __________________________________________  (0: Released)
bus_busy       __________________________________________  (0: Bus Free)
```

#### 3. 원하는 테스트 결과 (Scoreboard 확인 사항)
- **Scoreboard 확인 사항**: 의도치 않은 트랜잭션 캡처 0건 (`Total Transactions = 0`, `Matches = 0`, `Mismatches = 0`)
- **최종 판정**: `Errors = 0`, `Fatals = 0`, `TEST PASSED`

---

### TC002: `idle_test` (`tc_idle`)

#### 1. 원하는 시나리오 (Master / Slave 개수 포함)
- **구성**: **Master 1개 (`NUM_MASTER=1`, `M0`) : Slave DUT 1개 (`` `NUM_SLAVE=1 ``, `DUT_S0 @ 7'h2A`)**
- **호출 시퀀스**: `smbus_ip_idle_seq`
- **시나리오**: 리셋 해제 후 `#2000` 구간 동안 버스 자극 없이 대기하며 Pull-up 기반 Idle 상태(`SCL=1, SDA=1, bus_busy=0`) 지속성 확인.

#### 2. 테스트 Waveform
```text
Time(ns)       0    100            1100           2100
               |     |               |              |
rst_n          ______/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
SCL (tri1)     ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾  (Sustained High)
SDA (tri1)     ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾  (Sustained High)
bus_busy       ______________________________________  (0: Idle)
```

#### 3. 원하는 테스트 결과 (Scoreboard 확인 사항)
- **Scoreboard 확인 사항**: `Total Transactions = 0`, `Matches = 0`, `Mismatches = 0`
- **최종 판정**: `Errors = 0`, `Fatals = 0`, `TEST PASSED`

---

### TC003: `start_stop_test` (`tc_start_stop`)

#### 1. 원하는 시나리오 (Master / Slave 개수 포함)
- **구성**: **Master 1개 (`NUM_MASTER=1`, `M0`) : Slave DUT 1개 (`` `NUM_SLAVE=1 ``, `DUT_S0 @ 7'h2A`)**
- **호출 시퀀스**: `smbus_ip_start_stop_seq`
- **시나리오**: `M0`가 `START` → `Addr=0x2A, RW=0` (`Len=0`, Quick Command) 전송 → `DUT_S0`가 9번째 클럭에서 `ACK(0)` 응답 → `M0`가 즉시 `STOP` 발행.

#### 2. 테스트 Waveform
```text
Phase          IDLE   S   A6 A5 A4 A3 A2 A1 A0 RW  ACK   P   IDLE
Addr=0x2A(WR)             0  1  0  1  0  1  0  0   (0)
SCL            ‾‾‾‾‾‾‾‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾‾‾‾‾‾‾
SDA            ‾‾‾‾‾\___/‾‾‾\___/‾‾‾\___/‾‾‾\_______/‾‾‾‾\___/‾‾‾
M0_if.sda_oe   _____/‾‾‾\___/‾‾‾\___/‾‾‾\___/‾‾‾‾‾‾‾\____/‾‾‾\___
DUT_S0_sda_oe  ____________________________________/‾‾‾\_________ (ACK)
bus_busy       _____/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
```

#### 3. 원하는 테스트 결과 (Scoreboard 확인 사항)
- **Scoreboard 확인 사항**: `Addr=0x2A` 매칭 및 `ACK=1`(+1), `Len=0` Quick Command 처리(+1), `START=1` 확인 → `Total=1`, `Slave[0]=1`, `Matches=2`, `Mismatches=0`
- **최종 판정**: `Errors = 0`, `Fatals = 0`, `TEST PASSED`

---

### TC004: `write_test` (`tc_write`)

#### 1. 원하는 시나리오 (Master / Slave 개수 포함)
- **구성**: **Master 1개 (`NUM_MASTER=1`, `M0`) : Slave DUT 1개 (`` `NUM_SLAVE=1 ``, `DUT_S0 @ 7'h2A`)**
- **호출 시퀀스**: `smbus_ip_write_seq` (`Addr=7'h2A`, `Reg=8'h15`, `Data=8'hA5`)
- **시나리오**: `M0`가 `START` → `[0x2A|W]` → `[0x15]` → `[0xA5]` → `STOP` 전송. `DUT_S0`가 매 바이트 ACK 응답 후 `mem[0x15] = 0xA5` 기록, `reg_addr = 0x16` 증가.

#### 2. 테스트 Waveform
```text
Frame          [ S ] [ Addr=0x2A | W=0 ] [A] [ Reg=0x15 ] [A] [ Data=0xA5 ] [A] [ P ]
SCL            ‾‾‾\_/‾\_ ... _/‾\_/‾\_/‾\_/‾\_ ... _/‾\_/‾\_/‾\_ ... _/‾\_/‾\_/‾‾‾‾
SDA            ‾‾\_/< 0101_010_0 >[0]/< 0001_0101 >[0]/< 1010_0101 >[0]\_/‾‾‾
M0_if.sda_oe   __/‾ [  Address+W  ] _ [  Reg 0x15  ] _ [ Data 0xA5 ] _ /‾\___
DUT_S0_sda_oe  ____________________/‾\______________/‾\_____________/‾\______
bus_busy       __/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
```

#### 3. 원하는 테스트 결과 (Scoreboard 확인 사항)
- **Scoreboard 확인 사항**: `Addr=0x2A` ACK(+1), `RefMem[0][0x15]=0xA5` 및 `RefPtr[0]=0x16` 갱신(+1) → `Total=1`, `Slave[0]=1`, `Matches=2`, `Mismatches=0`
- **최종 판정**: `Errors = 0`, `Fatals = 0`, `TEST PASSED`

---

### TC005: `read_test` (`tc_read`)

#### 1. 원하는 시나리오 (Master / Slave 개수 포함)
- **구성**: **Master 1개 (`NUM_MASTER=1`, `M0`) : Slave DUT 1개 (`` `NUM_SLAVE=1 ``, `DUT_S0 @ 7'h2A`)**
- **호출 시퀀스**: `smbus_ip_read_seq` (`Addr=7'h2A`, `Reg=8'h02`)
- **시나리오**:
  1. `M0`가 Pointer Write `[0x2A|W] -> [0x02]` (`STOP=0`)로 `DUT_S0.reg_addr = 0x02` 설정.
  2. `STOP` 없이 `Repeated START(Sr)` → `[0x2A|R]` 요청 → `DUT_S0`가 초기 메모리 `mem[0x02] = 0xA2` 송신 → `M0` `NACK(1)` 후 `STOP`.

#### 2. 테스트 Waveform
```text
Frame          [ S ] [0x2A|W] [A] [Reg=0x02] [A] [Sr] [0x2A|R] [A] [Data=0xA2] [N] [ P ]
SCL            ‾‾\_/‾..._/‾\_/‾\_/‾..._/‾\_/‾\_/‾\_/‾..._/‾\_/‾\_/‾..._/‾\_/‾\_/‾‾‾
SDA            ‾\_/<01010100>[0]/<00000010>[0]‾\_/<01010101>[0]/<10100010>[1]\_/‾‾
M0_if.sda_oe   _/‾ [Addr+W ]  _  [Reg 0x02]  _ /‾ [Addr+R ]  _  [Release ]  _ /‾\__
DUT_S0_sda_oe  ______________/‾\____________/‾\_____________/‾\ [Drv 0xA2] ________
bus_busy       _/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
```

#### 3. 원하는 테스트 결과 (Scoreboard 확인 사항)
- **Scoreboard 확인 사항**: Trans #1 Pointer Write(`RefPtr[0]=0x02`, +2), Trans #2 Read `Actual 0xA2 == RefMem[0][0x02]` 일치(+2) → `Total=2`, `Slave[0]=2`, `Matches=4`, `Mismatches=0`
- **최종 판정**: `Errors = 0`, `Fatals = 0`, `TEST PASSED`

---

### TC006: `ack_test` (`tc_ack`)

#### 1. 원하는 시나리오 (Master / Slave 개수 포함)
- **구성**: **Master 1개 (`NUM_MASTER=1`, `M0`) : Slave DUT 1개 (`` `NUM_SLAVE=1 ``, `DUT_S0 @ 7'h2A`)**
- **호출 시퀀스**: `smbus_ip_ack_seq`
- **시나리오**: `M0`가 유효 주소 `7'h2A`로 Write `[0xAA]` 전송 시 `DUT_S0`가 9번째 클럭에서 `ACK (SDA=0)` 정상 구동 확인.

#### 2. 테스트 Waveform
```text
Frame          [ S ] [ Addr=0x2A | W=0 ] [ACK=0] [ Data=0xAA ] [ACK=0] [ P ]
SCL            ‾‾‾\_/‾\_ ... _/‾\_/‾\_/‾\_/‾\_ ... _/‾\_/‾\_/‾\_/‾‾‾‾
SDA            ‾‾\_/< 0101_010_0 >[  0  ]/< 1010_1010 >[  0  ]\_/‾‾‾
DUT_S0_sda_oe  ___________________/‾‾‾‾‾\______________/‾‾‾‾‾\______
bus_busy       __/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
```

#### 3. 원하는 테스트 결과 (Scoreboard 확인 사항)
- **Scoreboard 확인 사항**: `Addr=0x2A` 매칭 및 `ACK=1` 확인(+1), `RefPtr[0]=0xAA` 갱신(+1) → `Total=1`, `Slave[0]=1`, `Matches=2`, `Mismatches=0`
- **최종 판정**: `Errors = 0`, `Fatals = 0`, `TEST PASSED`

---

### TC007: `nack_test` (`tc_nack`)

#### 1. 원하는 시나리오 (Master / Slave 개수 포함)
- **구성**: **Master 1개 (`NUM_MASTER=1`, `M0`) : Slave DUT 1개 (`` `NUM_SLAVE=1 ``, `DUT_S0 @ 7'h2A`)**
- **호출 시퀀스**: `smbus_ip_nack_seq`
- **시나리오**: `M0`가 미할당 주소 `7'h55`로 Write 시도 → `DUT_S0 (0x2A)`는 미응답(SDA Release → `NACK=1`) → `M0` 즉시 `STOP` 발행.

#### 2. 테스트 Waveform
```text
Frame          [ S ] [ Addr=0x55 | W=0 ] [NACK=1] [ P ]   IDLE
SCL            ‾‾‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾‾‾‾‾
SDA            ‾‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾‾‾‾\___/‾‾‾‾‾
M0_if.sda_oe   __/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\_/‾\____/‾‾‾\_____
DUT_S0_sda_oe  _______________________________________________  (No ACK)
bus_busy       __/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_____
```

#### 3. 원하는 테스트 결과 (Scoreboard 확인 사항)
- **Scoreboard 확인 사항**: `find_slave_index(7'h55) == -1`, `NACK=1` 정상 판정(+1), `Slave[0] Trans = 0` → `Total=1`, `Matches=1`, `Mismatches=0`
- **최종 판정**: `Errors = 0`, `Fatals = 0`, `TEST PASSED`

---

### TC008: `multi_byte_test` (`tc_multi_byte`)

#### 1. 원하는 시나리오 (Master / Slave 개수 포함)
- **구성**: **Master 1개 (`NUM_MASTER=1`, `M0`) : Slave DUT 1개 (`` `NUM_SLAVE=1 ``, `DUT_S0 @ 7'h2A`)**
- **호출 시퀀스**: `smbus_ip_multi_byte_seq`
- **시나리오**: `M0`가 `0x2A`로 5바이트 Burst Write `[0x20, 0xDE, 0xAD, 0xBE, 0xEF]` 전송 → `DUT_S0`가 `mem[0x20..0x23]`에 순차 기록 후 포인터 `0x24`로 자동 증가.

#### 2. 테스트 Waveform
```text
Frame          [S][0x2A|W][A][0x20][A][0xDE][A][0xAD][A][0xBE][A][0xEF][A][P]
SCL            ‾\_/‾..._/‾\_/‾..._/‾\_/‾..._/‾\_/‾..._/‾\_/‾..._/‾\_/‾..._/‾‾
SDA            \_/<Addr+W>[0]<0x20>[0]<0xDE>[0]<0xAD>[0]<0xBE>[0]<0xEF>[0]\_/‾
DUT_S0_sda_oe  ___________/‾\______/‾\______/‾\______/‾\______/‾\______/‾\___
bus_busy       _/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\__
```

#### 3. 원하는 테스트 결과 (Scoreboard 확인 사항)
- **Scoreboard 확인 사항**: `Addr=0x2A` ACK(+1), `RefMem[0][0x20..0x23] = {0xDE, 0xAD, 0xBE, 0xEF}` 및 `RefPtr[0]=0x24` 갱신(+1) → `Total=1`, `Slave[0]=1`, `Matches=2`, `Mismatches=0`
- **최종 판정**: `Errors = 0`, `Fatals = 0`, `TEST PASSED`

---

### TC009: `restart_test` (`tc_restart`)

#### 1. 원하는 시나리오 (Master / Slave 개수 포함)
- **구성**: **Master 1개 (`NUM_MASTER=1`, `M0`) : Slave DUT 1개 (`` `NUM_SLAVE=1 ``, `DUT_S0 @ 7'h2A`)**
- **호출 시퀀스**: `smbus_ip_restart_seq`
- **시나리오**: `M0`가 Write `[0x30, 0x77]` (`STOP=0`)로 `mem[0x30]=0x77` 기록 및 `reg_addr=0x31` 이동 후, `STOP` 없이 `Repeated START(Sr)`로 Read (`Len=1`) 요청하여 `mem[0x31] = 0xD1` 수신 확인.

#### 2. 테스트 Waveform
```text
Frame          [S][0x2A|W][A][0x30][A][0x77][A][Sr][0x2A|R][A][0xD1][N][P]
SCL            ‾\_/‾.._/‾\_/‾.._/‾\_/‾.._/‾\_/‾\_/‾.._/‾\_/‾.._/‾\_/‾‾
SDA            \_/<Addr+W>[0]<0x30>[0]<0x77>[0]‾\_/<Addr+R>[0]<0xD1>[1]\_/‾
DUT_S0_sda_oe  ___________/‾\______/‾\______/‾\____________/‾\[0xD1]_______
bus_busy       _/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
```

#### 3. 원하는 테스트 결과 (Scoreboard 확인 사항)
- **Scoreboard 확인 사항**: Trans #1 Write(`mem[0x30]=0x77, ptr=0x31`, +2), Trans #2 Repeated START Read(`Actual 0xD1 == RefMem[0][0x31]`, +2) → `Total=2`, `Slave[0]=2`, `Matches=4`, `Mismatches=0`
- **최종 판정**: `Errors = 0`, `Fatals = 0`, `TEST PASSED`

---

### TC010: `random_test` (`tc_random`)

#### 1. 원하는 시나리오 (Master / Slave 개수 포함)
- **구성**: **Master 1개 (`NUM_MASTER=1`, `M0`) : Slave DUT 1개 (`` `NUM_SLAVE=1 ``, `DUT_S0 @ 7'h2A`)**
- **호출 시퀀스**: `smbus_ip_random_seq` (`m_n_num_trans = 8`)
- **시나리오**: `M0`가 `0x2A` 대상으로 8회 연속 랜덤 R/W 및 페이로드 트랜잭션을 수행해 `DUT_S0` 메모리/포인터 정합성 검증.

#### 2. 테스트 Waveform
```text
Trans #1(WR)   [S][0x2A|W][A][D0][A]...[Dk][A][P]  t_BUF
Trans #2(RD)                                      [S][0x2A|R][A][R0][A]...[Rm][N][P] ... (x8)
SCL            ‾\_/‾..._/‾\_/‾..._/‾\_/‾..._/‾‾‾‾‾‾\_/‾..._/‾\_/‾..._/‾\_/‾..._/‾‾‾
bus_busy       _/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\__
```

#### 3. 원하는 테스트 결과 (Scoreboard 확인 사항)
- **Scoreboard 확인 사항**: 8개 트랜잭션 전체 `Addr=0x2A` ACK 및 모든 Read/Write 바이트 `RefMem` 일치 → `Total=8`, `Slave[0]=8`, `Mismatches=0`
- **최종 판정**: `Errors = 0`, `Fatals = 0`, `TEST PASSED`

---

## Multi-Master / Multi-Slave 토폴로지 테스트 (`1:1`, `2:1`, `1:2`, `2:2`)

모든 토폴로지 테스트는 단일 Parameterized 테스트 클래스 `tc_multi_topo #(NUM_MASTER)`와 `hdl_top`의 `` `NUM_SLAVE `` define 조합으로 구성됩니다.
- Master별 비중첩 레지스터 파티션: `M0` → `0x10..0x1F`, `M1` → `0x30..0x3F`
- `(Master m, Slave s)` 쌍당 검증 항목:
  1. 단일 Write + Repeated-START Readback × 2회 (6건)
  2. 3바이트 Burst Write + Repeated-START 3바이트 Readback × 1회 (3건)
  3. `M0` 추가 검증: 미할당 주소 `7'h55` NACK 프로브 × 1회 (1건)

---

### TC011-1: `1:1` 검증 (`topo_1x1_test` / `topo_m1_test` + `` `NUM_SLAVE=1 ``)

#### 1. 원하는 시나리오 (Master / Slave 개수 포함)
- **구성**: **Master 1개 (`smbus_ip_env #(.NUM_MASTER(1))` → `M0`) : Slave DUT 1개 (`hdl_top +define+NUM_SLAVE=1` → `DUT_S0 @ 7'h2A`)**
- **실행 커맨드**: `.\compile.bat 1 ; .\run.ps1 topo_1x1_test` (또는 `topo_m1_test`)
- **시나리오**:
  1. `M0`가 `master_vif_0`를 통해 `DUT_S0 (0x2A)`의 `reg[0x10]=0xC0`, `reg[0x11]=0xC1` 단일 Write 및 Repeated-START Readback 검증.
  2. `M0`가 `reg[0x18..0x1A]`에 3바이트 Burst Write `[0xB0, 0xD0, 0xE0]` 후 Repeated-START 3바이트 Readback 검증.
  3. `M0`가 미할당 주소 `0x55` 전송 후 NACK 검증.

#### 2. 테스트 Waveform
```text
Op 1..2 (WR/RD) [S][0x2A|W][A][0x10][A][0xC0][A][P] [S][0x2A|W][A][0x10][A][Sr][0x2A|R][A][0xC0][N][P]
Burst (3B)      [S][0x2A|W][A][0x18][A][0xB0][A][0xD0][A][0xE0][A][P]
                [S][0x2A|W][A][0x18][A][Sr][0x2A|R][A][0xB0][A][0xD0][A][0xE0][N][P]
NACK Probe      [S][0x55|W][N][P]

SCL (tri1)      ‾\_/‾.._/‾\_/‾.._/‾\_/‾.._/‾‾‾‾‾\_/‾.._/‾\_/‾\_/‾.._/‾\_/‾.._/‾‾
M0_if.sda_oe    _/‾ [  Write / Ptr / Read ] \___/‾ [  Ptr  ] /‾ [  Read  ] \___
DUT_S0_sda_oe   _______/‾\_____/‾\_____/‾\___________/‾\___/‾\___/‾\[Data]_____
bus_busy        _/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_____/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\____
```

#### 3. 원하는 테스트 결과 (Scoreboard 확인 사항)
- **Scoreboard 확인 사항**:
  - `Active Slaves = 1`, `Slave[0] (0x2A) Trans = 9`, `0x55` NACK 1건
  - Write 6건 RefMem 갱신, Read 3건(총 5바이트) 데이터 100% 일치
  - **결과**: `Total Transactions = 10`, `Matches = 21`, `Mismatches = 0`
- **Activity & 최종 판정**: `M0 Trans = 10`, `DUT_S0 CheckedTrans = 9`, `Errors = 0`, `TEST PASSED`

---

### TC011-2: `2:1` 검증 (`topo_2x1_test` / `topo_m2_test` + `` `NUM_SLAVE=1 ``)

#### 1. 원하는 시나리오 (Master / Slave 개수 포함)
- **구성**: **Master 2개 (`smbus_ip_env #(.NUM_MASTER(2))` → `M0`, `M1`) : Slave DUT 1개 (`hdl_top +define+NUM_SLAVE=1` → `DUT_S0 @ 7'h2A`)**
- **실행 커맨드**: `.\compile.bat 1 ; .\run.ps1 topo_2x1_test` (또는 `topo_m2_test`)
- **시나리오**:
  1. `M0` (`master_vif_0`)와 `M1` (`master_vif_1`)가 공유 Open-Drain 버스(`scl`, `sda`)에서 `fork ... join_none; wait fork`로 **동시에** 단일 `DUT_S0 (0x2A)`에 접근.
  2. `bus_busy == 1` 대기 및 동시 START 경합 시 Open-Drain SDA Arbitration Loss 감지 후 자동 재시도(`m_n_arb_loss_count`) 수행.
  3. `M0`는 `0x10..0x1A`, `M1`은 `0x30..0x3A` 독립 영역에 Write/Readback 및 3바이트 Burst Write/Readback을 교차 실행하며 Pointer Write(`STOP=0`) ~ Repeated START Read(`STOP=1`)의 버스 점유 원자성 검증.
  4. `M0`가 미할당 주소 `0x55` NACK 검증 추가 수행.

#### 2. 테스트 Waveform
```text
Event           M0 wins bus (WR 0x10=0xC0)           M1 waits bus_busy=1 -> wins next (Ptr+Sr+RD 0x30)
                |                                    |
SCL (tri1)      ‾\_/‾.._/‾\_/‾.._/‾\_/‾.._/‾‾‾‾‾‾‾‾‾\_/‾.._/‾\_/‾.._/‾\_/‾\_/‾.._/‾\_/‾.._/‾‾
SDA (tri1)      \_/<0x2A|W>[0]<0x10>[0]<0xC0>[0]\_/‾\_/<0x2A|W>[0]<0x30>[0]‾\_/<0x2A|R>[0]<0xD0>[1]\_/‾
M0_if.sda_oe    _/‾ [  M0 drives 0x2A Write  ] \______(wait bus_busy=1 / arb retry)____________
M1_if.sda_oe    ____(wait bus_busy=1 / arb retry)___/‾ [ M1 Ptr 0x30 ] /‾ [ M1 Read 0x30 ] \___
DUT_S0_sda_oe   ___________/‾\______/‾\______/‾\______________/‾\______/‾\_________/‾\[0xD0]___
bus_busy        _/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
                                               t_BUF                      ^-- Sr (M0 차단)
```

#### 3. 원하는 테스트 결과 (Scoreboard 확인 사항)
- **Scoreboard 확인 사항**:
  - `Active Slaves = 1`, `Slave[0] (0x2A) Trans = 18` (`M0` 9건 + `M1` 9건), `0x55` NACK 1건
  - `M0` 영역(`0x10..0x1A`)과 `M1` 영역(`0x30..0x3A`)이 동시 경합 중에도 상호 오염 없이 100% 일치
  - **결과**: `Total Transactions = 19`, `Matches = 41`, `Mismatches = 0`
- **Activity & 최종 판정**: `M0 Trans = 10`, `M1 Trans = 9`, `DUT_S0 CheckedTrans = 18`, `Errors = 0`, `TEST PASSED`

---

### TC011-3: `1:2` 검증 (`topo_1x2_test` / `topo_m1_test` + `` `NUM_SLAVE=2 ``)

#### 1. 원하는 시나리오 (Master / Slave 개수 포함)
- **구성**: **Master 1개 (`smbus_ip_env #(.NUM_MASTER(1))` → `M0`) : Slave DUT 2개 (`hdl_top +define+NUM_SLAVE=2` → `DUT_S0 @ 7'h2A`, `DUT_S1 @ 7'h2B`)**
- **실행 커맨드**: `.\compile.bat 2 ; .\run.ps1 topo_1x2_test` (또는 `topo_m1_test`)
- **시나리오**:
  1. `M0`가 `DUT_S0 (0x2A)` 대상으로 단일 Write/Readback 2회 + 3바이트 Burst Write/Readback 수행 (`DUT_S1`은 침묵).
  2. 이어서 `M0`가 `DUT_S1 (0x2B)` 대상으로 동일하게 단일 Write/Readback 2회(`0xC1`, `0xC0`) + 3바이트 Burst Write/Readback(`[0xB0, 0xD1, 0xE1]`) 수행 (`DUT_S0`은 침묵).
  3. `M0`가 미할당 주소 `0x55` 전송 시 `DUT_S0`, `DUT_S1` 모두 응답하지 않아 `NACK` 발생 확인.

#### 2. 테스트 Waveform
```text
Event           M0 -> DUT_S0 (0x2A) WR [0x10, 0xC0]      M0 -> DUT_S1 (0x2B) Ptr+Sr+RD [0x10 -> 0xC1]
                |                                        |
SCL (tri1)      ‾\_/‾.._/‾\_/‾.._/‾\_/‾.._/‾‾‾‾‾‾‾‾‾‾‾‾‾\_/‾.._/‾\_/‾.._/‾\_/‾\_/‾.._/‾\_/‾.._/‾‾
SDA (tri1)      \_/<0x2A|W>[0]<0x10>[0]<0xC0>[0]\_/‾‾‾‾‾\_/<0x2B|W>[0]<0x10>[0]‾\_/<0x2B|R>[0]<0xC1>[1]\_/‾
M0_if.sda_oe    _/‾ [  M0 Write to 0x2A      ] \________/‾ [ M0 Ptr 0x2B ] /‾ [ M0 Read 0x2B ] \_____
DUT_S0_sda_oe   ___________/‾\______/‾\______/‾\_____________________________________________________ (Only S0 ACKs 0x2A)
DUT_S1_sda_oe   __________________________________________________/‾\______/‾\_________/‾\[0xC1]_____ (Only S1 ACKs/Drives 0x2B)
bus_busy        _/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_______/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
```

#### 3. 원하는 테스트 결과 (Scoreboard 확인 사항)
- **Scoreboard 확인 사항**:
  - `Active Slaves = 2`, `Slave[0] (0x2A) Trans = 9`, `Slave[1] (0x2B) Trans = 9`, `0x55` NACK 1건
  - 두 슬레이브의 독립 Reference Memory(`m_an_slave_ref_mem[0]`, `m_an_slave_ref_mem[1]`)가 서로 간섭 없이 정확히 분리 검증됨
  - **결과**: `Total Transactions = 19`, `Matches = 41`, `Mismatches = 0`
- **Activity & 최종 판정**: `M0 Trans = 19`, `DUT_S0 CheckedTrans = 9`, `DUT_S1 CheckedTrans = 9`, `Errors = 0`, `TEST PASSED`

---

### TC011-4: `2:2` 검증 (`topo_2x2_test` / `topo_m2_test` + `` `NUM_SLAVE=2 ``)

#### 1. 원하는 시나리오 (Master / Slave 개수 포함)
- **구성**: **Master 2개 (`smbus_ip_env #(.NUM_MASTER(2))` → `M0`, `M1`) : Slave DUT 2개 (`hdl_top +define+NUM_SLAVE=2` → `DUT_S0 @ 7'h2A`, `DUT_S1 @ 7'h2B`)**
- **실행 커맨드**: `.\compile.bat 2 ; .\run.ps1 topo_2x2_test` (또는 `topo_m2_test`)
- **시나리오**:
  1. `M0` (`master_vif_0`)와 `M1` (`master_vif_1`)가 공유 버스에서 동시 실행되며, 각각 `DUT_S0 (0x2A)`와 `DUT_S1 (0x2B)` 모두에 대해 단일 Write/Readback 2회 + 3바이트 Burst Write/Readback 수행.
  2. Multi-Master 버스 경합(Arbitration & `bus_busy` 대기)과 Multi-Slave 주소 라우팅(`0x2A` vs `0x2B` 배타적 ACK/Read 구동)을 동시에 검증.
  3. `M0`가 미할당 주소 `0x55` 전송 시 두 DUT 슬레이브 모두 미응답(`NACK`) 확인.

#### 2. 테스트 Waveform
```text
Event           M0 -> DUT_S0 (0x2A) WR [0x10, 0xC0]      M1 -> DUT_S1 (0x2B) Ptr+Sr+RD [0x30 -> 0xD1]
                |                                        |
SCL (tri1)      ‾\_/‾.._/‾\_/‾.._/‾\_/‾.._/‾‾‾‾‾‾‾‾‾‾‾‾‾\_/‾.._/‾\_/‾.._/‾\_/‾\_/‾.._/‾\_/‾.._/‾‾
SDA (tri1)      \_/<0x2A|W>[0]<0x10>[0]<0xC0>[0]\_/‾‾‾‾‾\_/<0x2B|W>[0]<0x30>[0]‾\_/<0x2B|R>[0]<0xD1>[1]\_/‾
M0_if.sda_oe    _/‾ [  M0 drives 0x2A Write  ] \__________(wait bus_busy=1 / arb retry)______________
M1_if.sda_oe    ____(wait bus_busy=1 / arb retry)_______/‾ [ M1 Ptr 0x2B ] /‾ [ M1 Read 0x2B ] \_____
DUT_S0_sda_oe   ___________/‾\______/‾\______/‾\_____________________________________________________ (Only S0 ACKs 0x2A)
DUT_S1_sda_oe   __________________________________________________/‾\______/‾\_________/‾\[0xD1]_____ (Only S1 ACKs/Drives 0x2B)
bus_busy        _/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\_______/‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾\___
                                                t_BUF                        ^-- Sr (M0 차단)
```

#### 3. 원하는 테스트 결과 (Scoreboard 확인 사항)
- **Scoreboard 확인 사항**:
  - `Active Slaves = 2`, `Slave[0] (0x2A) Trans = 18` (`M0` 9 + `M1` 9), `Slave[1] (0x2B) Trans = 18` (`M0` 9 + `M1` 9), `0x55` NACK 1건
  - `M0`/`M1`의 각 슬레이브별 레지스터 영역 및 Burst 데이터 100% 일치
  - **결과**: `Total Transactions = 37`, `Matches = 81`, `Mismatches = 0`
- **Activity & 최종 판정**: `M0 Trans = 19`, `M1 Trans = 18`, `DUT_S0 CheckedTrans = 18`, `DUT_S1 CheckedTrans = 18`, `Errors = 0`, `TEST PASSED`
