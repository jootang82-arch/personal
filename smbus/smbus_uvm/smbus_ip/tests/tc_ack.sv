`ifndef TC_ACK_SV
`define TC_ACK_SV

class tc_ack extends tc_base;

    typedef tc_ack                          t_tc_ack;
    typedef smbus_ip_ack_seq                t_smbus_ip_ack_seq;

    `uvm_component_utils(tc_ack)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "tc_ack", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction

    // ========================================
    // run_phase
    // ========================================
    task run_phase(uvm_phase phase);
        smbus_ip_ack_seq st_seq;
        super.run_phase(phase);

        phase.raise_objection(this, "Starting tc_ack");
        `uvm_info("TC_ACK", "Starting TC006: SMBus ACK Verification Test", UVM_LOW)

        st_seq = smbus_ip_ack_seq::type_id::create("st_seq");
        st_seq.start(this.m_st_env.m_st_smbus_master_agt.m_st_sqr);

        #1500;
        phase.drop_objection(this, "Completed tc_ack");
    endtask

endclass

class ack_test extends tc_ack;
    `uvm_component_utils(ack_test)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "ack_test", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction
endclass

`endif // TC_ACK_SV
