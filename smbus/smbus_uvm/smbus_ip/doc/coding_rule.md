# SMBus UVM Verification Environment Coding Rule

본 문서는 `smbus_uvm` 프로젝트 내 모든 SystemVerilog 및 UVM 소스 코드에 적용되는 필수 코딩 표준을 정의합니다.

---

## 1. 멤버 변수 Naming Convention

Class 및 Struct 내에 선언되는 모든 멤버 변수는 데이터 타입에 따라 아래 Prefix를 반드시 사용합니다.

| 데이터 타입 | Naming Rule | 적용 예시 |
|---|---|---|
| **Integer** | `m_n_` | `m_n_count`, `m_n_data_len`, `m_n_timeout_limit_ns` |
| **Logic / Bit** | `m_n_` | `m_n_enable`, `m_n_rw`, `m_n_ack`, `m_n_nack` |
| **String** | `m_s_` | `m_s_name`, `m_s_test_name` |
| **Integer / Logic / Bit Array** | `m_an_` | `m_an_data[]`, `m_an_mem[]` |
| **String Array** | `m_as_` | `m_as_name[]` |
| **Class Handle / Struct** | `m_st_` | `m_st_master_sqr`, `m_st_drv`, `m_st_env`, `m_st_vif` |
| **Class / Struct Array 및 Queue**| `m_ast_`| `m_ast_expected_queue[$]`, `m_ast_config[]` |

---

## 2. Local Variable 및 Argument Naming Convention

함수(Function) 및 태스크(Task) 내부에서 선언되는 지역 변수와 매개변수(Argument)는 멤버 변수 Prefix에서 `m_`만 제거하여 사용합니다.

| 멤버 변수 대응 형태 | Local Variable / Argument Naming | 적용 예시 |
|---|---|---|
| `m_n_*` | `n_*` | `n_count`, `n_enable`, `n_addr`, `n_rw` |
| `m_s_*` | `s_*` | `s_name`, `s_err_type`, `s_msg` |
| `m_an_*` | `an_*` | `an_data[]`, `an_payload[]` |
| `m_st_*` | `st_*` | `st_trans`, `st_req`, `st_seq`, `st_vif` |
| `m_ast_*` | `ast_*` | `ast_items[]` |

---

## 3. Class 및 Type Naming Convention

- Class 이름은 파일명과 일치시키며 `st_` Prefix를 붙이지 않습니다 (`st_` / `m_st_`는 Class·Struct **변수/핸들** 선언 시에만 사용).
  - Class 이름 예: `smbus_transaction`, `smbus_master_drv`, `smbus_ip_env`, `tc_base`
  - 변수 이름 예: `smbus_ip_env m_st_env;`, `smbus_transaction st_tr;`
- Enum 정의는 별도의 Package 전역 영역에 선언하지 않고, 관련 Class 내부에 선언합니다 (`smbus_ip_types`).

---

## 4. `this.` Keyword 필수 사용 규칙 (최우선 준수 규칙)

Class 내 Function 및 Task에서 자신의 멤버 변수에 접근하거나 멤버 메소드를 호출할 때 **반드시 `this.`을 붙여야 합니다.**

### 4.1 멤버 변수 접근 시
```systemverilog
// [BAD] 금지 사항: this. 누락
function void set_addr(bit [6:0] n_addr);
    m_n_slave_addr = n_addr;
endfunction

// [GOOD] 준수 사항: 반드시 this. 명시
function void set_addr(bit [6:0] n_addr);
    this.m_n_slave_addr = n_addr;
endfunction

// [GOOD] 멤버 변수 Read 시에도 this. 필수
function bit [6:0] get_addr();
    return this.m_n_slave_addr;
endfunction
```

### 4.2 클래스 멤버 메소드(Function / Task) 호출 시
```systemverilog
// [BAD] 금지 사항: this. 누락
task run_phase(uvm_phase phase);
    drive_idle();
endtask

// [GOOD] 준수 사항: 반드시 this. 명시
task run_phase(uvm_phase phase);
    this.drive_idle();
endtask
```

---

## 5. 추가 코딩 가이드라인

1. **UVM Factory Registration**:
   - 모든 UVM Object는 `` `uvm_object_utils `` 또는 `` `uvm_object_utils_begin ``을 등록합니다.
   - 모든 UVM Component는 `` `uvm_component_utils ``를 등록합니다.
2. **UVM Standard Reporting Macro**:
   - `$display`를 직접 사용하지 않고 `` `uvm_info ``, `` `uvm_warning ``, `` `uvm_error ``, `` `uvm_fatal ``을 사용합니다.
3. **Open-Drain 버스 제어**:
   - SDA/SCL은 High 상태를 직접 구동(1'b1)하지 않고 Release(1'bz)하여 Pull-up에 의해 High가 되도록 구현합니다.
4. **Header Guard**:
   - 모든 `.sv` 및 `.pkg` 파일은 중복 include를 방지하기 위해 `` `ifndef ``, `` `define ``, `` `endif `` 가드를 포함합니다.
5. **UVM 전용 메소드 vs 사용자 정의 메소드 배치 규칙**:
   - UVM 전용 메소드(`new`, `build_phase`, `connect_phase`, `end_of_elaboration_phase`, `run_phase`, `report_phase`, `pre_body`, `body`, `post_body`, `post_randomize`, `convert2string`, `write_*`)는 `class ... endclass` 내부에 직접 구현합니다.
   - 그 외 사용자 정의 `function` 및 `task`는 클래스 내부에 `extern`으로 선언하고, 구현부는 `endclass` 밖에 `ClassName::method_name` 형태로 작성합니다.
6. **Function / Task 상단 구분 주석**:
   - 모든 `function` 및 `task` 구현부 상단에는 아래 형식의 구분 주석을 작성합니다:
     ```systemverilog
     // ========================================
     // <method_name>
     // ========================================
     ```
