# SMBus UVM IP Verification Plan

## 1. 개요 (Overview)
본 검증 계획서는 SystemVerilog 및 UVM (Universal Verification Methodology)을 기반으로 한 재사용 가능한 SMBus (System Management Bus) Agent 및 IP Verification Environment에 대한 검증 전략과 범위를 기술합니다.

- **대상 프로토콜**: SMBus Specification 2.0 (Physical & Data Link Layer)
- **검증 방법론**: IEEE 1800 SystemVerilog / IEEE 1800.2 UVM
- **환경 구성**: 독립형 SMBus Master Agent, Slave Agent, 공용 Monitor, Scoreboard, IP Base Sequence 및 Test Library

---

## 2. 검증 범위 및 프로토콜 기능 (Verification Scope)

| 프로토콜 항목 | 검증 내용 및 기준 |
|---|---|
| **Bus Idle** | SCL 및 SDA 신호가 Pull-up 저항에 의해 모두 High 상태를 유지하는지 확인 |
| **START Condition** | SCL=High 상태에서 SDA가 Falling Edge를 생성하는지 검출 |
| **STOP Condition** | SCL=High 상태에서 SDA가 Rising Edge를 생성하는지 검출 |
| **Repeated START** | STOP 없이 SCL=High 상태에서 새로운 START condition을 생성하는 동작 검증 |
| **Slave Address** | 7-bit Slave Address 송수신 및 Address Matching 동작 검증 |
| **R/W Direction** | 8번째 비트의 Read(1'b1) / Write(1'b0) 방향 구분 및 제어 |
| **ACK (Acknowledge)** | 9번째 클럭에서 SDA=Low (ACK) 응답 구동 및 샘플링 검증 |
| **NACK (Not Ack)** | 주소 불일치 또는 데이터 수신 거부 시 SDA=High (NACK) 검증 |
| **Data Transfer** | 8-bit Data 바이트의 MSB-first 정상 송수신 검증 |
| **Multi-byte Burst** | 단일 트랜잭션 내 다중 바이트 연속 쓰기/읽기 및 자동 주소 증가 검증 |
| **Open-Drain 특성** | Master/Slave 양방향 버스 구동 시 Drive Low & Release High 충돌 방지 |
| **PEC (Packet Error)** | CRC-8 다항식 ($X^8 + X^2 + X + 1$, 0x07) 기반 에러 체크 기능 |
| **Clock Stretching** | Slave가 SCL을 Low로 잡아당겨 전송 지연을 유발할 때 Master의 대기 동작 |

---

## 3. 검증 환경 아키텍처 (Testbench Architecture)

```
                            +-------------------------------------------------------------+
                            |                       tc_base / Tests                    |
                            +-------------------------------------------------------------+
                                                          |
                            +-------------------------------------------------------------+
                            |                      smbus_ip_env                        |
                            |                                                             |
                            |   +-----------------------+     +-----------------------+   |
                            |   |  smbus_master_agt  |     |  smbus_slave_agt   |   |
                            |   |  - smbus_master_sqr|     |  - smbus_slave_sqr |   |
                            |   |  - smbus_master_drv|     |  - smbus_slave_drv |   |
                            |   +-----------+-----------+     +-----------+-----------+   |
                            |               |                             |               |
                            |   +-----------v-----------------------------v-----------+   |
                            |   |                 smbus_mon (Common)               |   |
                            |   +---------------------------+-------------------------+   |
                            |                               | analysis_port               |
                            |   +---------------------------v-------------------------+   |
                            |   |                 smbus_ip_scoreboard              |   |
                            |   +-----------------------------------------------------+   |
                            +-------------------------------------------------------------+
                                                          | virtual smbus_if
                            +-------------------------------------------------------------+
                            |                 hdl_top / smbus_if / DUT                    |
                            +-------------------------------------------------------------+
```

### 3.1 주요 컴포넌트 역할
1. **smbus_master_agt**: Master Sequencer와 Driver를 포함하여 시뮬레이션 자극(Stimulus)을 생성하고 SMBus 인터페이스에 Protocol을 구동합니다.
2. **smbus_slave_agt**: Slave Sequencer와 Driver를 포함하여 반응형 응답 및 독립적인 Slave 동작을 모델링합니다.
3. **smbus_mon**: Master/Slave 공용 Monitor로, DUT 내부 신호가 아닌 SCL/SDA physical bus 신호만을 관찰하여 트랜잭션을 디코딩하고 Scoreboard로 전송합니다.
4. **smbus_ip_scoreboard**: Monitor가 전송한 Actual 트랜잭션과 Reference Model의 Expected 데이터를 비교하여 무결성을 검증합니다.
5. **smbus_if**: Open-Drain 구조와 Pull-up 저항을 모델링한 SystemVerilog 인터페이스입니다.

---

## 4. 테스트 케이스 정의 (Testcases Matrix)

| Test ID | Test Name | 목적 및 검증 시나리오 | 예상 결과 |
|---|---|---|---|
| **TC001** | `reset_test` | 리셋 인가 시 및 해제 후 버스 상태 관찰 | 버스 Idle(SCL=1, SDA=1) 확인, 에러 0건 |
| **TC002** | `idle_test` | 버스 Idle 상태 유지 및 pull-up 동작 검증 | SCL/SDA High 유지 확인, 에러 0건 |
| **TC003** | `start_stop_test` | START 및 STOP condition 생성 및 디코딩 검증 | START/STOP 순서 정확 검출, 에러 0건 |
| **TC004** | `write_test` | Slave Address `0x2A`로 레지스터 쓰기 트랜잭션 수행 | Slave ACK 및 Reference Mem 갱신 일치 |
| **TC005** | `read_test` | Pointer 쓰기 후 Restart를 통한 1바이트 읽기 수행 | Slave 응답 데이터와 Reference Mem 데이터 일치 |
| **TC006** | `ack_test` | 유효한 슬레이브 주소 (`0x2A`) 전송 시 ACK 확인 | 9번째 클럭에서 SDA=0 확인 및 Scoreboard PASS |
| **TC007** | `nack_test` | 존재하지 않는 주소 (`0x55`) 전송 시 NACK 확인 | 9번째 클럭에서 SDA=1 (NACK) 확인 |
| **TC008** | `multi_byte_test` | 다중 바이트 (5바이트) 연속 버스트 쓰기 전송 | 모든 바이트 순차 쓰기 및 데이터 일치 검증 |
| **TC009** | `restart_test` | 쓰기 후 STOP 없이 Repeated START로 읽기 전환 | 버스 해제 없이 Repeated START 정확 검출 |
| **TC010** | `random_test` | 주소, R/W, 페이로드 길이 랜덤 트랜잭션 8회 반복 | 모든 랜덤 트랜잭션 Scoreboard Mismatch 0건 |
| **TC011** | `topo_1x1_test`, `topo_2x1_test`, `topo_1x2_test`, `topo_2x2_test` | Single VIP + `smbus_ip_env #(NUM_MASTER)` + `hdl_top` `` `NUM_SLAVE `` 기반 `1:1`, `2:1`, `1:2`, `2:2` 검증 | 다중 Master Arbitration, 다중 DUT Slave 주소 라우팅 및 Scoreboard Mismatch 0건 |

> 각 TC별 상세 시나리오(Master/Slave 수), 버스 Waveform, Scoreboard 검증 항목 및 결과는 [test_scenarios.md](./test_scenarios.md)를 참조하세요.

---

## 5. 완료 기준 (Acceptance Criteria)

1. 전체 소스 코드 문법 오류 0건 및 UVM 컴파일 성공
2. UVM Topology Elaboration 성공
3. TC001 ~ TC010 전체 테스트 시뮬레이션 PASS
4. Scoreboard Mismatch 0건
5. `UVM_ERROR` = 0, `UVM_FATAL` = 0
6. 코딩 규칙 (`this.` 키워드 및 Naming Convention) 100% 준수
