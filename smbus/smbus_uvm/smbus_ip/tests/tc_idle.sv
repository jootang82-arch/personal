`ifndef TC_IDLE_SV
`define TC_IDLE_SV

class tc_idle extends tc_base;

    typedef tc_idle                         t_tc_idle;
    typedef smbus_ip_idle_seq               t_smbus_ip_idle_seq;

    `uvm_component_utils(tc_idle)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "tc_idle", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction

    // ========================================
    // run_phase
    // ========================================
    task run_phase(uvm_phase phase);
        smbus_ip_idle_seq st_seq;
        super.run_phase(phase);

        phase.raise_objection(this, "Starting tc_idle");
        `uvm_info("TC_IDLE", "Starting TC002: SMBus Bus Idle Test", UVM_LOW)

        st_seq = smbus_ip_idle_seq::type_id::create("st_seq");
        st_seq.start(this.m_st_env.m_st_smbus_master_agt.m_st_sqr);

        #1000;
        phase.drop_objection(this, "Completed tc_idle");
    endtask

endclass

class idle_test extends tc_idle;
    `uvm_component_utils(idle_test)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "idle_test", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction
endclass

`endif // TC_IDLE_SV
