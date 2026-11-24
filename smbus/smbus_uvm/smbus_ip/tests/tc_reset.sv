`ifndef TC_RESET_SV
`define TC_RESET_SV

class tc_reset extends tc_base;

    typedef tc_reset                        t_tc_reset;
    typedef smbus_ip_reset_seq              t_smbus_ip_reset_seq;

    `uvm_component_utils(tc_reset)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "tc_reset", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction

    // ========================================
    // run_phase
    // ========================================
    task run_phase(uvm_phase phase);
        smbus_ip_reset_seq st_seq;
        super.run_phase(phase);

        phase.raise_objection(this, "Starting tc_reset");
        `uvm_info("TC_RESET", "Starting TC001: SMBus Reset Test", UVM_LOW)

        st_seq = smbus_ip_reset_seq::type_id::create("st_seq");
        st_seq.start(this.m_st_env.m_st_smbus_master_agt.m_st_sqr);

        #500;
        phase.drop_objection(this, "Completed tc_reset");
    endtask

endclass

class reset_test extends tc_reset;
    `uvm_component_utils(reset_test)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "reset_test", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction
endclass

`endif // TC_RESET_SV
