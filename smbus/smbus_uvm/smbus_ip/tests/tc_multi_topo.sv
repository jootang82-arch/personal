`ifndef TC_MULTI_TOPO_SV
`define TC_MULTI_TOPO_SV

// ==============================================================================
// Unified Parameterized SMBus Master:Slave Topology Verification Test
//   - Master count: NUM_MASTER parameter -> smbus_ip_env #(NUM_MASTER)
//   - Slave count : `NUM_SLAVE define in hdl_top -> smbus_ip_slave_model DUTs
//   - Supported Topologies:
//       1:1 -> `NUM_SLAVE=1 + topo_m1_test (or topo_1x1_test)
//       2:1 -> `NUM_SLAVE=1 + topo_m2_test (or topo_2x1_test)
//       1:2 -> `NUM_SLAVE=2 + topo_m1_test (or topo_1x2_test)
//       2:2 -> `NUM_SLAVE=2 + topo_m2_test (or topo_2x2_test)
// ==============================================================================
class tc_multi_topo #(
    int NUM_MASTER = 1
) extends tc_base_param #(NUM_MASTER);

    typedef tc_multi_topo #(NUM_MASTER)     t_tc_multi_topo;
    typedef smbus_ip_master_worker_seq      t_smbus_ip_master_worker_seq;

    int                                     m_n_ops_per_slave;
    bit                                     m_n_concurrent;
    int                                     m_n_expected_slaves;

    `uvm_component_param_utils(tc_multi_topo #(NUM_MASTER))

    // ========================================
    // new
    // ========================================
    function new(string s_name = "tc_multi_topo", uvm_component st_parent = null);
        super.new(s_name, st_parent);
        this.m_n_ops_per_slave   = 2;
        this.m_n_concurrent      = 1'b1;
        this.m_n_expected_slaves = 0; // 0 = auto-adapt to compiled `NUM_SLAVE
    endfunction

    // ========================================
    // build_phase
    // ========================================
    function void build_phase(uvm_phase phase);
        int n_plusarg_val;

        if ($value$plusargs("NUM_OPS=%d", n_plusarg_val)) begin
            this.m_n_ops_per_slave = n_plusarg_val;
        end
        if ($value$plusargs("CONCURRENT=%d", n_plusarg_val)) begin
            this.m_n_concurrent = (n_plusarg_val != 0);
        end

        super.build_phase(phase);

        if (this.m_n_expected_slaves > 0 && this.m_n_num_slaves != this.m_n_expected_slaves) begin
            `uvm_fatal("TC_TOPO", $sformatf("Compiled `NUM_SLAVE=%0d in hdl_top does not match test expectation (%0d). Recompile with +define+NUM_SLAVE=%0d.",
                       this.m_n_num_slaves, this.m_n_expected_slaves, this.m_n_expected_slaves))
        end
    endfunction

    // ========================================
    // run_phase
    // ========================================
    task run_phase(uvm_phase phase);
        bit [6:0] an_slave_addrs[];
        string    s_topo_label;

        super.run_phase(phase);
        phase.raise_objection(this, "Starting tc_multi_topo");

        s_topo_label = $sformatf("%0d:%0d (NUM_MASTER=%0d, `NUM_SLAVE=%0d)",
                                 NUM_MASTER, this.m_n_num_slaves, NUM_MASTER, this.m_n_num_slaves);

        `uvm_info("TC_TOPO", $sformatf("Starting Topology Test: %s | Concurrent=%0b | Ops/Slave=%0d",
                  s_topo_label, this.m_n_concurrent, this.m_n_ops_per_slave), UVM_LOW)

        an_slave_addrs = new[this.m_n_num_slaves];
        for (int s = 0; s < this.m_n_num_slaves; s++) begin
            an_slave_addrs[s] = smbus_ip_port::SMBUS_DEFAULT_SLAVE_ADDR + s[6:0];
            `uvm_info("TC_TOPO", $sformatf("  Active HDL DUT Slave[%0d] Address = 0x%02h", s, an_slave_addrs[s]), UVM_LOW)
        end

        if (this.m_n_concurrent && NUM_MASTER > 1) begin
            // Spawn all NUM_MASTER single-master VIP agents concurrently on shared physical bus
            fork
                begin : multi_master_fork_group
                    for (int m = 0; m < NUM_MASTER; m++) begin
                        automatic int n_mid = m;
                        fork
                            begin
                                this.run_master_worker(n_mid, an_slave_addrs);
                            end
                        join_none
                    end
                    wait fork;
                end
            join
        end else begin
            for (int m = 0; m < NUM_MASTER; m++) begin
                this.run_master_worker(m, an_slave_addrs);
            end
        end

        #3000;
        this.verify_topology_activity();
        phase.drop_objection(this, "Completed tc_multi_topo");
    endtask

    // ========================================
    // External non-UVM method prototypes
    // ========================================
    extern task run_master_worker(int n_mid, bit [6:0] an_slave_addrs[]);
    extern function void verify_topology_activity();

endclass

// ========================================
// run_master_worker
// ========================================
task tc_multi_topo #(int NUM_MASTER)::run_master_worker(int n_mid, bit [6:0] an_slave_addrs[]);
    smbus_ip_master_worker_seq st_seq;
    st_seq = smbus_ip_master_worker_seq::type_id::create($sformatf("st_worker_m%0d", n_mid));
    st_seq.m_n_master_id     = n_mid;
    st_seq.m_n_ops_per_slave = this.m_n_ops_per_slave;
    st_seq.m_n_check_nack    = (n_mid == 0);
    st_seq.m_an_target_addrs = new[an_slave_addrs.size()];
    for (int s = 0; s < an_slave_addrs.size(); s++) begin
        st_seq.m_an_target_addrs[s] = an_slave_addrs[s];
    end
    st_seq.start(this.m_st_env.m_ast_master_agt[n_mid].m_st_sqr);
endtask

// ========================================
// verify_topology_activity
// ========================================
function void tc_multi_topo #(int NUM_MASTER)::verify_topology_activity();
    for (int m = 0; m < NUM_MASTER; m++) begin
        int n_tx_cnt;
        int n_arb_cnt;
        n_tx_cnt  = this.m_st_env.m_ast_master_agt[m].m_st_drv.m_n_trans_count;
        n_arb_cnt = this.m_st_env.m_ast_master_agt[m].m_st_drv.m_n_arb_loss_count;
        `uvm_info("TC_TOPO", $sformatf("Master[%0d] Summary: Transactions=%0d, ArbitrationRetries=%0d",
                  m, n_tx_cnt, n_arb_cnt), UVM_LOW)
        if (n_tx_cnt == 0) begin
            `uvm_error("TC_TOPO", $sformatf("Master[%0d] executed 0 transactions!", m))
        end
    end

    for (int s = 0; s < this.m_n_num_slaves; s++) begin
        int n_sb_cnt;
        bit [6:0] n_saddr;
        n_sb_cnt = this.m_st_env.m_st_scoreboard.m_an_slave_trans_cnt[s];
        n_saddr  = this.m_st_env.m_st_scoreboard.m_an_slave_addrs[s];
        `uvm_info("TC_TOPO", $sformatf("HDL DUT Slave[%0d] (Addr=0x%02h) Summary: CheckedTrans=%0d",
                  s, n_saddr, n_sb_cnt), UVM_LOW)
        if (n_sb_cnt == 0) begin
            `uvm_error("TC_TOPO", $sformatf("HDL DUT Slave[%0d] (Addr=0x%02h) received 0 transactions!", s, n_saddr))
        end
    end
endfunction

// ==============================================================================
// Auto-Adapting Parameterized Master Entry Points (adapts to `NUM_SLAVE=1 or 2)
// ==============================================================================
class topo_m1_test extends tc_multi_topo #(1);
    `uvm_component_utils(topo_m1_test)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "topo_m1_test", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction
endclass

class topo_m2_test extends tc_multi_topo #(2);
    `uvm_component_utils(topo_m2_test)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "topo_m2_test", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction
endclass

// ==============================================================================
// Explicit Topology Tests: 1:1, 2:1, 1:2, 2:2
// ==============================================================================
class topo_1x1_test extends tc_multi_topo #(1);
    `uvm_component_utils(topo_1x1_test)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "topo_1x1_test", uvm_component st_parent = null);
        super.new(s_name, st_parent);
        this.m_n_expected_slaves = 1;
    endfunction
endclass

class topo_2x1_test extends tc_multi_topo #(2);
    `uvm_component_utils(topo_2x1_test)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "topo_2x1_test", uvm_component st_parent = null);
        super.new(s_name, st_parent);
        this.m_n_expected_slaves = 1;
    endfunction
endclass

class topo_1x2_test extends tc_multi_topo #(1);
    `uvm_component_utils(topo_1x2_test)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "topo_1x2_test", uvm_component st_parent = null);
        super.new(s_name, st_parent);
        this.m_n_expected_slaves = 2;
    endfunction
endclass

class topo_2x2_test extends tc_multi_topo #(2);
    `uvm_component_utils(topo_2x2_test)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "topo_2x2_test", uvm_component st_parent = null);
        super.new(s_name, st_parent);
        this.m_n_expected_slaves = 2;
    endfunction
endclass

`endif // TC_MULTI_TOPO_SV
