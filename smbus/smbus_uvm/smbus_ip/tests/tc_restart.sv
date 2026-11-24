`ifndef TC_RESTART_SV
`define TC_RESTART_SV

class tc_restart extends tc_base;

    typedef tc_restart                      t_tc_restart;
    typedef smbus_ip_restart_seq            t_smbus_ip_restart_seq;

    `uvm_component_utils(tc_restart)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "tc_restart", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction

    // ========================================
    // run_phase
    // ========================================
    task run_phase(uvm_phase phase);
        smbus_ip_restart_seq st_seq;
        super.run_phase(phase);

        phase.raise_objection(this, "Starting tc_restart");
        `uvm_info("TC_RESTART", "Starting TC009: SMBus Repeated START Test", UVM_LOW)

        st_seq = smbus_ip_restart_seq::type_id::create("st_seq");
        st_seq.start(this.m_st_env.m_st_smbus_master_agt.m_st_sqr);

        #3000;
        phase.drop_objection(this, "Completed tc_restart");
    endtask

endclass

class restart_test extends tc_restart;
    `uvm_component_utils(restart_test)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "restart_test", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction
endclass

`endif // TC_RESTART_SV
