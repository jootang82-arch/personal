`ifndef TC_BASE_SV
`define TC_BASE_SV

// ==============================================================================
// Parameterized Test Base Class (NUM_MASTER passed to smbus_ip_env #(NUM_MASTER))
// ==============================================================================
class tc_base_param #(
    int NUM_MASTER = 1
) extends uvm_test;

    typedef tc_base_param #(NUM_MASTER)     t_tc_base_param;
    typedef smbus_ip_env #(NUM_MASTER)      t_smbus_ip_env;
    typedef virtual smbus_if                t_smbus_vif;

    t_smbus_ip_env                          m_st_env;
    t_smbus_vif                             m_st_vif;

    int                                     m_n_num_masters;
    int                                     m_n_num_slaves;

    `uvm_component_param_utils(tc_base_param #(NUM_MASTER))

    // ========================================
    // new
    // ========================================
    function new(string s_name = "tc_base_param", uvm_component st_parent = null);
        super.new(s_name, st_parent);
        this.m_n_num_masters = NUM_MASTER;
        this.m_n_num_slaves  = 1;
    endfunction

    // ========================================
    // build_phase
    // ========================================
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(t_smbus_vif)::get(this, "", "vif", this.m_st_vif)) begin
            `uvm_fatal("TC_BASE", "Virtual interface smbus_if not found in config_db")
        end

        // Retrieve compiled `NUM_SLAVE count exported by hdl_top
        void'(uvm_config_db#(int)::get(this, "", "num_slaves", this.m_n_num_slaves));

        // Pass common virtual interface and slave count to IP environment
        uvm_config_db#(t_smbus_vif)::set(this, "m_st_env", "vif", this.m_st_vif);
        uvm_config_db#(int)::set(this, "m_st_env", "num_slaves", this.m_n_num_slaves);

        // Create parameterized IP Environment with NUM_MASTER master agent(s)
        this.m_st_env = t_smbus_ip_env::type_id::create("m_st_env", this);
    endfunction

    // ========================================
    // connect_phase
    // ========================================
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // Connect static sequencers for legacy IP sequence access
        smbus_ip_base_sequence::m_st_master_sqr = this.m_st_env.m_st_smbus_master_agt.m_st_sqr;
        smbus_ip_base_sequence::m_st_slave_sqr  = this.m_st_env.m_st_smbus_slave_agt.m_st_sqr;

        // Set test name to scoreboard
        this.m_st_env.m_st_scoreboard.m_s_test_name = this.get_name();

        // Disable optional VIP Slave Agent ACK when HDL DUT slave_model(s) are active in hdl_top
        if (this.m_st_env.m_st_smbus_slave_agt != null &&
            this.m_st_env.m_st_smbus_slave_agt.m_st_drv != null) begin
            this.m_st_env.m_st_smbus_slave_agt.m_st_drv.m_n_enable_ack = 1'b0;
        end
    endfunction

    // ========================================
    // end_of_elaboration_phase
    // ========================================
    function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        `uvm_info("TC_BASE", $sformatf("Architecture: VIP Master(s) [NUM_MASTER=%0d] <-> HDL DUT Slave Model(s) [`NUM_SLAVE=%0d]",
                  this.m_n_num_masters, this.m_n_num_slaves), UVM_LOW)
        `uvm_info("TC_BASE", "UVM Elaboration completed. Printing component topology:", UVM_LOW)
        this.print();
    endfunction

    // ========================================
    // run_phase
    // ========================================
    task run_phase(uvm_phase phase);
        // Base run phase sets drain time
        phase.phase_done.set_drain_time(this, 1000ns);
    endtask

    // ========================================
    // report_phase
    // ========================================
    function void report_phase(uvm_phase phase);
        uvm_report_server st_server;
        int n_err_cnt;
        int n_fatal_cnt;

        super.report_phase(phase);
        st_server   = uvm_report_server::get_server();
        n_err_cnt   = st_server.get_severity_count(UVM_ERROR);
        n_fatal_cnt = st_server.get_severity_count(UVM_FATAL);

        `uvm_info("TC_BASE", $sformatf({
            "\n=======================================================\n",
            "                    TEST SUMMARY REPORT                \n",
            "=======================================================\n",
            "  Test Name    : %s\n",
            "  Mode         : VIP Master(s) <-> HDL DUT Slave(s)\n",
            "  Topology     : %0d Master(s) : %0d Slave(s)\n",
            "  Errors       : %0d\n",
            "  Fatals       : %0d\n",
            "  Result       : %s\n",
            "======================================================="},
            this.get_name(),
            this.m_n_num_masters,
            this.m_n_num_slaves,
            n_err_cnt, n_fatal_cnt,
            ((n_err_cnt == 0 && n_fatal_cnt == 0) ? "TEST PASSED" : "TEST FAILED")), UVM_NONE)
    endfunction

endclass

// ==============================================================================
// Default Legacy Test Base Class (NUM_MASTER = 1 for TC001 ~ TC010)
// ==============================================================================
class tc_base extends tc_base_param #(1);

    typedef tc_base                         t_tc_base;

    `uvm_component_utils(tc_base)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "tc_base", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction

endclass

`endif // TC_BASE_SV
