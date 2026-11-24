`ifndef TC_RANDOM_SV
`define TC_RANDOM_SV

class tc_random extends tc_base;

    typedef tc_random                       t_tc_random;
    typedef smbus_ip_random_seq             t_smbus_ip_random_seq;

    `uvm_component_utils(tc_random)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "tc_random", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction

    // ========================================
    // run_phase
    // ========================================
    task run_phase(uvm_phase phase);
        smbus_ip_random_seq st_seq;
        super.run_phase(phase);

        phase.raise_objection(this, "Starting tc_random");
        `uvm_info("TC_RANDOM", "Starting TC010: SMBus Random Transaction Test", UVM_LOW)

        st_seq = smbus_ip_random_seq::type_id::create("st_seq");
        st_seq.m_n_num_trans = 8;
        st_seq.start(this.m_st_env.m_st_smbus_master_agt.m_st_sqr);

        #5000;
        phase.drop_objection(this, "Completed tc_random");
    endtask

endclass

class random_test extends tc_random;
    `uvm_component_utils(random_test)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "random_test", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction
endclass

`endif // TC_RANDOM_SV
