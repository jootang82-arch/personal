`ifndef TC_READ_SV
`define TC_READ_SV

class tc_read extends tc_base;

    typedef tc_read                         t_tc_read;
    typedef smbus_ip_read_seq               t_smbus_ip_read_seq;

    `uvm_component_utils(tc_read)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "tc_read", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction

    // ========================================
    // run_phase
    // ========================================
    task run_phase(uvm_phase phase);
        smbus_ip_read_seq st_seq;
        super.run_phase(phase);

        phase.raise_objection(this, "Starting tc_read");
        `uvm_info("TC_READ", "Starting TC005: SMBus Master Read Test", UVM_LOW)

        st_seq = smbus_ip_read_seq::type_id::create("st_seq");
        st_seq.m_n_slave_addr = 7'h2A;
        st_seq.m_n_reg_addr   = 8'h02;
        st_seq.start(this.m_st_env.m_st_smbus_master_agt.m_st_sqr);

        #2000;
        phase.drop_objection(this, "Completed tc_read");
    endtask

endclass

class read_test extends tc_read;
    `uvm_component_utils(read_test)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "read_test", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction
endclass

`endif // TC_READ_SV
