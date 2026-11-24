`ifndef TC_MULTI_BYTE_SV
`define TC_MULTI_BYTE_SV

class tc_multi_byte extends tc_base;

    typedef tc_multi_byte                   t_tc_multi_byte;
    typedef smbus_ip_multi_byte_seq         t_smbus_ip_multi_byte_seq;

    `uvm_component_utils(tc_multi_byte)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "tc_multi_byte", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction

    // ========================================
    // run_phase
    // ========================================
    task run_phase(uvm_phase phase);
        smbus_ip_multi_byte_seq st_seq;
        super.run_phase(phase);

        phase.raise_objection(this, "Starting tc_multi_byte");
        `uvm_info("TC_MULTI", "Starting TC008: SMBus Multi-byte Transfer Test", UVM_LOW)

        st_seq = smbus_ip_multi_byte_seq::type_id::create("st_seq");
        st_seq.start(this.m_st_env.m_st_smbus_master_agt.m_st_sqr);

        #3000;
        phase.drop_objection(this, "Completed tc_multi_byte");
    endtask

endclass

class multi_byte_test extends tc_multi_byte;
    `uvm_component_utils(multi_byte_test)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "multi_byte_test", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction
endclass

`endif // TC_MULTI_BYTE_SV
