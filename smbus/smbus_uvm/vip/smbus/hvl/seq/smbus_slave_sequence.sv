`ifndef SMBUS_SLAVE_SEQUENCE_SV
`define SMBUS_SLAVE_SEQUENCE_SV

class smbus_slave_sequence extends smbus_base_sequence;

    typedef smbus_slave_sequence            t_smbus_slave_sequence;
    typedef smbus_transaction               t_smbus_transaction;

    rand bit [6:0]                          m_n_resp_addr;
    rand bit                                m_n_ack_enable;
    rand bit [7:0]                          m_an_resp_data[];

    `uvm_object_utils(smbus_slave_sequence)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_slave_sequence");
        super.new(s_name);
        this.m_n_resp_addr    = 7'h2A;
        this.m_n_ack_enable   = 1'b1;
        this.m_an_resp_data   = new[4];
        this.m_an_resp_data[0]= 8'h11;
        this.m_an_resp_data[1]= 8'h22;
        this.m_an_resp_data[2]= 8'h33;
        this.m_an_resp_data[3]= 8'h44;
    endfunction

    // ========================================
    // body
    // ========================================
    task body();
        smbus_transaction st_tr;
        st_tr = smbus_transaction::type_id::create("st_tr");

        this.start_item(st_tr);
        st_tr.m_n_slave_addr = this.m_n_resp_addr;
        st_tr.m_n_ack        = this.m_n_ack_enable;
        st_tr.set_payload(this.m_an_resp_data);
        this.finish_item(st_tr);
    endtask

endclass

`endif // SMBUS_SLAVE_SEQUENCE_SV
