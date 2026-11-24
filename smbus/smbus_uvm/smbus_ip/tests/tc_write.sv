`ifndef TC_WRITE_SV
`define TC_WRITE_SV

class tc_write extends tc_base;

    typedef tc_write                        t_tc_write;
    typedef smbus_ip_write_seq              t_smbus_ip_write_seq;

    `uvm_component_utils(tc_write)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "tc_write", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction

    // ========================================
    // run_phase
    // ========================================
    task run_phase(uvm_phase phase);
        smbus_ip_write_seq st_seq;
        super.run_phase(phase);

        phase.raise_objection(this, "Starting tc_write");
        `uvm_info("TC_WRITE", "Starting TC004: SMBus Master Write Test", UVM_LOW)

        st_seq = smbus_ip_write_seq::type_id::create("st_seq");
        st_seq.m_n_slave_addr = 7'h2A;
        st_seq.m_n_reg_addr   = 8'h15;
        st_seq.m_n_write_data = 8'hA5;
        st_seq.start(this.m_st_env.m_st_smbus_master_agt.m_st_sqr);

        #2000;
        phase.drop_objection(this, "Completed tc_write");
    endtask

endclass

class write_test extends tc_write;
    `uvm_component_utils(write_test)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "write_test", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction
endclass

`endif // TC_WRITE_SV
