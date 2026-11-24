`ifndef SMBUS_IP_SCOREBOARD_SV
`define SMBUS_IP_SCOREBOARD_SV

`uvm_analysis_imp_decl(_mon)

class smbus_ip_scoreboard extends uvm_scoreboard;

    typedef smbus_ip_scoreboard                                                 t_smbus_ip_scoreboard;
    typedef smbus_transaction                                                   t_smbus_transaction;
    typedef uvm_analysis_imp_mon #(t_smbus_transaction, t_smbus_ip_scoreboard)  t_mon_export;

    localparam int MAX_SLAVES = 4;

    t_mon_export                                                                m_st_mon_export;
    bit [7:0]                                                                   m_an_ref_mem [0:255];
    bit [7:0]                                                                   m_n_ref_ptr;
    bit [6:0]                                                                   m_n_expected_slave_addr;

    // Multi-slave reference state (supports 1..4 slaves simultaneously)
    int                                                                         m_n_num_slaves;
    bit [6:0]                                                                   m_an_slave_addrs [0:MAX_SLAVES-1];
    bit [7:0]                                                                   m_an_slave_ref_mem [0:MAX_SLAVES-1][0:255];
    bit [7:0]                                                                   m_an_slave_ref_ptr [0:MAX_SLAVES-1];
    int                                                                         m_an_slave_trans_cnt [0:MAX_SLAVES-1];

    int                                                                         m_n_total_trans;
    int                                                                         m_n_match_count;
    int                                                                         m_n_mismatch_count;
    string                                                                      m_s_test_name;

    `uvm_component_utils(smbus_ip_scoreboard)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_ip_scoreboard", uvm_component st_parent = null);
        super.new(s_name, st_parent);
        this.m_n_expected_slave_addr = 7'h2A;
        this.m_n_ref_ptr             = 8'h00;
        this.m_n_num_slaves          = 1;
        this.m_n_total_trans         = 0;
        this.m_n_match_count         = 0;
        this.m_n_mismatch_count      = 0;
        this.m_s_test_name           = "smbus_test";

        // Preload expected slave memories with initial values matching slave model / VIP slave driver
        for (int s = 0; s < MAX_SLAVES; s++) begin
            this.m_an_slave_addrs[s]     = 7'h2A + s[6:0];
            this.m_an_slave_ref_ptr[s]   = 8'h00;
            this.m_an_slave_trans_cnt[s] = 0;
            for (int i = 0; i < 256; i++) begin
                this.m_an_slave_ref_mem[s][i] = 8'hA0 + i[7:0];
            end
        end
        for (int i = 0; i < 256; i++) begin
            this.m_an_ref_mem[i] = 8'hA0 + i[7:0];
        end
    endfunction

    // ========================================
    // build_phase
    // ========================================
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        this.m_st_mon_export = new("m_st_mon_export", this);
    endfunction

    // ========================================
    // write_mon
    // ========================================
    function void write_mon(smbus_transaction st_trans);
        this.check_transaction(st_trans);
    endfunction

    // ========================================
    // report_phase
    // ========================================
    function void report_phase(uvm_phase phase);
        string s_slave_summary;
        super.report_phase(phase);

        s_slave_summary = "";
        for (int s = 0; s < this.m_n_num_slaves; s++) begin
            s_slave_summary = {s_slave_summary, $sformatf("  Slave[%0d] (Addr=0x%02h) Trans : %0d\n",
                               s, this.m_an_slave_addrs[s], this.m_an_slave_trans_cnt[s])};
        end

        `uvm_info("SCOREBOARD", $sformatf({
            "\n=======================================================\n",
            "               SCOREBOARD SUMMARY REPORT               \n",
            "=======================================================\n",
            "  Active Slaves              : %0d\n",
            "%s",
            "  Total Transactions Checked : %0d\n",
            "  Matches                    : %0d\n",
            "  Mismatches                 : %0d\n",
            "  Status                     : %s\n",
            "======================================================="},
            this.m_n_num_slaves,
            s_slave_summary,
            this.m_n_total_trans,
            this.m_n_match_count,
            this.m_n_mismatch_count,
            (this.m_n_mismatch_count == 0 ? "PASSED" : "FAILED")), UVM_LOW)

        if (this.m_n_mismatch_count > 0) begin
            `uvm_error("SCOREBOARD", "Verification finished with Scoreboard mismatches!")
        end
    endfunction

    // ========================================
    // External non-UVM method prototypes
    // ========================================
    extern function void configure_slaves(int n_num_slaves, bit [6:0] an_addrs[]);
    extern function int  find_slave_index(bit [6:0] n_addr);
    extern function void check_transaction(smbus_transaction st_trans);
    extern function void report_mismatch(string s_err_type, string s_exp, string s_act);

endclass

// ========================================
// configure_slaves
// ========================================
function void smbus_ip_scoreboard::configure_slaves(int n_num_slaves, bit [6:0] an_addrs[]);
    if (n_num_slaves < 1 || n_num_slaves > MAX_SLAVES) begin
        `uvm_fatal("SCOREBOARD", $sformatf("Invalid slave count %0d (must be 1..%0d)", n_num_slaves, MAX_SLAVES))
    end
    this.m_n_num_slaves = n_num_slaves;
    for (int s = 0; s < n_num_slaves; s++) begin
        if (s < an_addrs.size()) begin
            this.m_an_slave_addrs[s] = an_addrs[s];
        end else begin
            this.m_an_slave_addrs[s] = 7'h2A + s[6:0];
        end
        this.m_an_slave_ref_ptr[s]   = 8'h00;
        this.m_an_slave_trans_cnt[s] = 0;
        for (int i = 0; i < 256; i++) begin
            this.m_an_slave_ref_mem[s][i] = 8'hA0 + i[7:0];
        end
    end
    this.m_n_expected_slave_addr = this.m_an_slave_addrs[0];
endfunction

// ========================================
// find_slave_index
// ========================================
function int smbus_ip_scoreboard::find_slave_index(bit [6:0] n_addr);
    for (int s = 0; s < this.m_n_num_slaves; s++) begin
        if (this.m_an_slave_addrs[s] === n_addr) begin
            return s;
        end
    end
    return -1;
endfunction

// ========================================
// check_transaction
// ========================================
function void smbus_ip_scoreboard::check_transaction(smbus_transaction st_trans);
    int n_slave_idx;

    this.m_n_total_trans++;

    `uvm_info("SCOREBOARD", $sformatf("Evaluating Transaction #%0d: %s",
              this.m_n_total_trans, st_trans.convert2string()), UVM_MEDIUM)

    // 1. Verify Address Matching & Response (ACK / NACK) across all active slaves
    n_slave_idx = this.find_slave_index(st_trans.m_n_slave_addr);
    if (n_slave_idx < 0) begin
        // Non-matching address must receive NACK
        if (st_trans.m_n_nack == 1'b1) begin
            this.m_n_match_count++;
            `uvm_info("SCOREBOARD", $sformatf("PASS: Non-matching address 0x%02h correctly NACKed",
                      st_trans.m_n_slave_addr), UVM_HIGH)
        end else begin
            this.report_mismatch("UNEXPECTED_ACK_ON_INVALID_ADDR", "NACK (1'b1)", "ACK (1'b0)");
        end
        return;
    end else begin
        // Matching address must receive ACK
        if (st_trans.m_n_nack == 1'b1) begin
            this.report_mismatch("UNEXPECTED_NACK_ON_VALID_ADDR", "ACK (1'b0)", "NACK (1'b1)");
            return;
        end else begin
            this.m_n_match_count++;
            this.m_an_slave_trans_cnt[n_slave_idx]++;
        end
    end

    // 2. Write Transaction Analysis
    if (st_trans.m_n_rw == 1'b0) begin
        if (st_trans.m_an_data.size() >= 2) begin
            bit [7:0] n_cur_ptr;
            n_cur_ptr = st_trans.m_an_data[0];
            for (int i = 1; i < st_trans.m_an_data.size(); i++) begin
                this.m_an_slave_ref_mem[n_slave_idx][n_cur_ptr] = st_trans.m_an_data[i];
                if (n_slave_idx == 0) begin
                    this.m_an_ref_mem[n_cur_ptr] = st_trans.m_an_data[i];
                end
                `uvm_info("SCOREBOARD", $sformatf("RefMem[S%0d@0x%02h] update: mem[0x%02h] = 0x%02h",
                          n_slave_idx, st_trans.m_n_slave_addr, n_cur_ptr, st_trans.m_an_data[i]), UVM_HIGH)
                n_cur_ptr++;
            end
            this.m_an_slave_ref_ptr[n_slave_idx] = n_cur_ptr;
            if (n_slave_idx == 0) begin
                this.m_n_ref_ptr = n_cur_ptr;
            end
            this.m_n_match_count++;
        end else if (st_trans.m_an_data.size() == 1) begin
            this.m_an_slave_ref_ptr[n_slave_idx] = st_trans.m_an_data[0];
            if (n_slave_idx == 0) begin
                this.m_n_ref_ptr = st_trans.m_an_data[0];
            end
            `uvm_info("SCOREBOARD", $sformatf("RefMem[S%0d@0x%02h] pointer set to 0x%02h",
                      n_slave_idx, st_trans.m_n_slave_addr, this.m_an_slave_ref_ptr[n_slave_idx]), UVM_HIGH)
            this.m_n_match_count++;
        end else begin
            // Quick command or probe write
            this.m_n_match_count++;
        end
    end
    // 3. Read Transaction Analysis
    else begin
        bit [7:0] n_base_ptr;
        n_base_ptr = this.m_an_slave_ref_ptr[n_slave_idx];
        for (int i = 0; i < st_trans.m_an_data.size(); i++) begin
            bit [7:0] n_expected_byte;
            bit [7:0] n_actual_byte;
            bit [7:0] n_addr_offset;

            n_addr_offset   = n_base_ptr + i[7:0];
            n_expected_byte = this.m_an_slave_ref_mem[n_slave_idx][n_addr_offset];
            n_actual_byte   = st_trans.m_an_data[i];

            if (n_expected_byte !== n_actual_byte) begin
                this.report_mismatch("READ_DATA_MISMATCH",
                                     $sformatf("S%0d@0x%02h[0x%02h]=0x%02h",
                                               n_slave_idx, st_trans.m_n_slave_addr, n_addr_offset, n_expected_byte),
                                     $sformatf("S%0d@0x%02h[0x%02h]=0x%02h",
                                               n_slave_idx, st_trans.m_n_slave_addr, n_addr_offset, n_actual_byte));
            end else begin
                this.m_n_match_count++;
                `uvm_info("SCOREBOARD", $sformatf("PASS: Read data match at S%0d@0x%02h[0x%02h] = 0x%02h",
                          n_slave_idx, st_trans.m_n_slave_addr, n_addr_offset, n_actual_byte), UVM_HIGH)
            end
        end
        this.m_an_slave_ref_ptr[n_slave_idx] = n_base_ptr + st_trans.m_an_data.size();
        if (n_slave_idx == 0) begin
            this.m_n_ref_ptr = this.m_an_slave_ref_ptr[0];
        end
    end

    // 4. Protocol integrity and PEC check
    if (st_trans.m_n_start !== 1'b1) begin
        this.report_mismatch("MISSING_START_CONDITION", "START=1", "START=0");
    end
    if (st_trans.m_n_pec_enable) begin
        bit [7:0] n_expected_pec;
        n_expected_pec = st_trans.compute_pec();
        if (st_trans.m_n_pec !== n_expected_pec) begin
            this.report_mismatch("PEC_MISMATCH",
                                 $sformatf("0x%02h", n_expected_pec),
                                 $sformatf("0x%02h", st_trans.m_n_pec));
        end else begin
            this.m_n_match_count++;
        end
    end
endfunction

// ========================================
// report_mismatch
// ========================================
function void smbus_ip_scoreboard::report_mismatch(string s_err_type, string s_exp, string s_act);
    this.m_n_mismatch_count++;
    `uvm_error("SCOREBOARD", $sformatf({
        "\n================ MISMATCH DETECTED ================\n",
        "  Test Name         : %s\n",
        "  Transaction Index : %0d\n",
        "  Expected Value    : %s\n",
        "  Actual Value      : %s\n",
        "  Error Type        : %s\n",
        "==================================================="},
        this.m_s_test_name, this.m_n_total_trans, s_exp, s_act, s_err_type))
endfunction

`endif // SMBUS_IP_SCOREBOARD_SV
