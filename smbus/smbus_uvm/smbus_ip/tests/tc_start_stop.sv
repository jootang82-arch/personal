`ifndef TC_START_STOP_SV
`define TC_START_STOP_SV

class tc_start_stop extends tc_base;

    typedef tc_start_stop                   t_tc_start_stop;
    typedef smbus_ip_start_stop_seq         t_smbus_ip_start_stop_seq;

    `uvm_component_utils(tc_start_stop)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "tc_start_stop", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction

    // ========================================
    // run_phase
    // ========================================
    task run_phase(uvm_phase phase);
        smbus_ip_start_stop_seq st_seq;
        super.run_phase(phase);

        phase.raise_objection(this, "Starting tc_start_stop");
        `uvm_info("TC_START_STOP", "Starting TC003: SMBus START/STOP Protocol Test", UVM_LOW)

        st_seq = smbus_ip_start_stop_seq::type_id::create("st_seq");
        st_seq.start(this.m_st_env.m_st_smbus_master_agt.m_st_sqr);

        #1000;
        phase.drop_objection(this, "Completed tc_start_stop");
    endtask

endclass

class start_stop_test extends tc_start_stop;
    `uvm_component_utils(start_stop_test)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "start_stop_test", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction
endclass

`endif // TC_START_STOP_SV
