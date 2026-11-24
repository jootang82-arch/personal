`ifndef SMBUS_MASTER_SEQUENCE_SV
`define SMBUS_MASTER_SEQUENCE_SV

class smbus_master_sequence extends smbus_base_sequence;

    typedef smbus_master_sequence           t_smbus_master_sequence;
    typedef smbus_transaction               t_smbus_transaction;

    `uvm_object_utils(smbus_master_sequence)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_master_sequence");
        super.new(s_name);
    endfunction

    // ========================================
    // External non-UVM method prototypes
    // ========================================
    extern task write_byte(bit [6:0] n_addr, bit [7:0] n_reg, bit [7:0] n_val);
    extern task read_byte(bit [6:0] n_addr, bit [7:0] n_reg, output bit [7:0] n_val);
    extern task burst_write(bit [6:0] n_addr, bit [7:0] an_payload[]);
    extern task burst_read(bit [6:0] n_addr, int n_len, output bit [7:0] an_data[]);
    extern task quick_cmd(bit [6:0] n_addr, bit n_rw);

endclass

// ========================================
// write_byte
// ========================================
task smbus_master_sequence::write_byte(bit [6:0] n_addr, bit [7:0] n_reg, bit [7:0] n_val);
    smbus_transaction st_tr;
    st_tr = smbus_transaction::type_id::create("st_tr");

    this.start_item(st_tr);
    st_tr.m_n_slave_addr = n_addr;
    st_tr.m_n_rw         = 1'b0; // Write
    st_tr.m_an_data      = new[2];
    st_tr.m_an_data[0]   = n_reg;
    st_tr.m_an_data[1]   = n_val;
    st_tr.m_n_data_len   = 2;
    st_tr.m_n_start      = 1'b1;
    st_tr.m_n_stop       = 1'b1;
    this.finish_item(st_tr);
endtask

// ========================================
// read_byte
// ========================================
task smbus_master_sequence::read_byte(bit [6:0] n_addr, bit [7:0] n_reg, output bit [7:0] n_val);
    smbus_transaction st_wr;
    smbus_transaction st_rd;

    // Step 1: Write register address pointer (Restart without stop)
    st_wr = smbus_transaction::type_id::create("st_wr");
    this.start_item(st_wr);
    st_wr.m_n_slave_addr = n_addr;
    st_wr.m_n_rw         = 1'b0;
    st_wr.m_an_data      = new[1];
    st_wr.m_an_data[0]   = n_reg;
    st_wr.m_n_data_len   = 1;
    st_wr.m_n_start      = 1'b1;
    st_wr.m_n_stop       = 1'b0; // Repeated START follows
    this.finish_item(st_wr);

    // Step 2: Read data byte with Repeated START
    st_rd = smbus_transaction::type_id::create("st_rd");
    this.start_item(st_rd);
    st_rd.m_n_slave_addr = n_addr;
    st_rd.m_n_rw         = 1'b1; // Read
    st_rd.m_n_data_len   = 1;
    st_rd.m_n_start      = 1'b1;
    st_rd.m_n_restart    = 1'b1;
    st_rd.m_n_stop       = 1'b1;
    this.finish_item(st_rd);

    if (st_rd.m_an_data.size() > 0) begin
        n_val = st_rd.m_an_data[0];
    end else begin
        n_val = 8'h00;
    end
endtask

// ========================================
// burst_write
// ========================================
task smbus_master_sequence::burst_write(bit [6:0] n_addr, bit [7:0] an_payload[]);
    smbus_transaction st_tr;
    st_tr = smbus_transaction::type_id::create("st_tr");

    this.start_item(st_tr);
    st_tr.m_n_slave_addr = n_addr;
    st_tr.m_n_rw         = 1'b0;
    st_tr.set_payload(an_payload);
    st_tr.m_n_start      = 1'b1;
    st_tr.m_n_stop       = 1'b1;
    this.finish_item(st_tr);
endtask

// ========================================
// burst_read
// ========================================
task smbus_master_sequence::burst_read(bit [6:0] n_addr, int n_len, output bit [7:0] an_data[]);
    smbus_transaction st_tr;
    st_tr = smbus_transaction::type_id::create("st_tr");

    this.start_item(st_tr);
    st_tr.m_n_slave_addr = n_addr;
    st_tr.m_n_rw         = 1'b1;
    st_tr.m_n_data_len   = n_len;
    st_tr.m_n_start      = 1'b1;
    st_tr.m_n_stop       = 1'b1;
    this.finish_item(st_tr);

    an_data = st_tr.m_an_data;
endtask

// ========================================
// quick_cmd
// ========================================
task smbus_master_sequence::quick_cmd(bit [6:0] n_addr, bit n_rw);
    smbus_transaction st_tr;
    st_tr = smbus_transaction::type_id::create("st_tr");

    this.start_item(st_tr);
    st_tr.m_n_slave_addr = n_addr;
    st_tr.m_n_rw         = n_rw;
    st_tr.m_n_data_len   = 0;
    st_tr.m_an_data      = new[0];
    st_tr.m_n_start      = 1'b1;
    st_tr.m_n_stop       = 1'b1;
    this.finish_item(st_tr);
endtask

`endif // SMBUS_MASTER_SEQUENCE_SV
