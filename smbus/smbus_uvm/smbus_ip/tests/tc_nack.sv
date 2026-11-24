`ifndef TC_NACK_SV
`define TC_NACK_SV

class tc_nack extends tc_base;

    typedef tc_nack                         t_tc_nack;
    typedef smbus_ip_nack_seq               t_smbus_ip_nack_seq;

    `uvm_component_utils(tc_nack)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "tc_nack", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction

    // ========================================
    // run_phase
    // ========================================
    task run_phase(uvm_phase phase);
        smbus_ip_nack_seq st_seq;
        super.run_phase(phase);

        phase.raise_objection(this, "Starting tc_nack");
        `uvm_info("TC_NACK", "Starting TC007: SMBus NACK Verification Test", UVM_LOW)

        st_seq = smbus_ip_nack_seq::type_id::create("st_seq");
        st_seq.start(this.m_st_env.m_st_smbus_master_agt.m_st_sqr);

        #1500;
        phase.drop_objection(this, "Completed tc_nack");
    endtask

endclass

class nack_test extends tc_nack;
    `uvm_component_utils(nack_test)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "nack_test", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction
endclass

`endif // TC_NACK_SV
