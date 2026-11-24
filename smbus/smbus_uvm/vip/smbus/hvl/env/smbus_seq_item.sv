`ifndef SMBUS_SEQ_ITEM_SV
`define SMBUS_SEQ_ITEM_SV

class smbus_transaction extends uvm_sequence_item;

    typedef smbus_transaction               t_smbus_transaction;

    rand bit [6:0]                          m_n_slave_addr;
    rand bit                                m_n_rw;
    rand bit [7:0]                          m_an_data[];
    rand bit                                m_n_ack;
    rand bit                                m_n_nack;
    rand bit                                m_n_pec_enable;
    rand bit [7:0]                          m_n_pec;

    // Additional protocol and control attributes
    rand bit [2:0]                          m_n_trans_type;
    rand int                                m_n_data_len;
    rand bit                                m_n_start;
    rand bit                                m_n_stop;
    rand bit                                m_n_restart;
    rand int                                m_n_stretch_cycles;
    rand bit [1:0]                          m_n_status;

    // Constraints
    constraint c_data_len {
        m_n_data_len inside {[0:32]};
        m_an_data.size() == m_n_data_len;
    }

    constraint c_default_control {
        soft m_n_start          == 1'b1;
        soft m_n_stop           == 1'b1;
        soft m_n_restart        == 1'b0;
        soft m_n_pec_enable     == 1'b0;
        soft m_n_stretch_cycles == 0;
        soft m_n_status         == 2'b00;
        soft m_n_ack            == 1'b0;
        soft m_n_nack           == 1'b0;
    }

    `uvm_object_utils_begin(smbus_transaction)
        `uvm_field_int         (m_n_slave_addr,     UVM_ALL_ON)
        `uvm_field_int         (m_n_rw,             UVM_ALL_ON)
        `uvm_field_array_int   (m_an_data,          UVM_ALL_ON)
        `uvm_field_int         (m_n_ack,            UVM_ALL_ON)
        `uvm_field_int         (m_n_nack,           UVM_ALL_ON)
        `uvm_field_int         (m_n_pec_enable,     UVM_ALL_ON)
        `uvm_field_int         (m_n_pec,            UVM_ALL_ON)
        `uvm_field_int         (m_n_trans_type,     UVM_ALL_ON)
        `uvm_field_int         (m_n_data_len,       UVM_ALL_ON)
        `uvm_field_int         (m_n_start,          UVM_ALL_ON)
        `uvm_field_int         (m_n_stop,           UVM_ALL_ON)
        `uvm_field_int         (m_n_restart,        UVM_ALL_ON)
        `uvm_field_int         (m_n_stretch_cycles, UVM_ALL_ON)
        `uvm_field_int         (m_n_status,         UVM_ALL_ON)
    `uvm_object_utils_end

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_transaction");
        super.new(s_name);
        this.m_n_start          = 1'b1;
        this.m_n_stop           = 1'b1;
        this.m_n_restart        = 1'b0;
        this.m_n_pec_enable     = 1'b0;
        this.m_n_stretch_cycles = 0;
        this.m_n_status         = 2'b00;
        this.m_n_ack            = 1'b0;
        this.m_n_nack           = 1'b0;
        this.m_n_data_len       = 0;
        this.m_an_data          = new[0];
    endfunction

    // ========================================
    // post_randomize
    // ========================================
    function void post_randomize();
        super.post_randomize();
        if (this.m_n_pec_enable) begin
            this.m_n_pec = this.compute_pec();
        end
    endfunction

    // ========================================
    // convert2string
    // ========================================
    function string convert2string();
        string s_str;
        s_str = $sformatf("SMBus Trans: Addr=0x%02h RW=%s Len=%0d ACK=%b NACK=%b PEC_EN=%b PEC=0x%02h Data=[",
                          this.m_n_slave_addr,
                          (this.m_n_rw ? "RD" : "WR"),
                          this.m_n_data_len,
                          this.m_n_ack,
                          this.m_n_nack,
                          this.m_n_pec_enable,
                          this.m_n_pec);
        for (int i = 0; i < this.m_an_data.size(); i++) begin
            s_str = {s_str, $sformatf(" 0x%02h", this.m_an_data[i])};
        end
        s_str = {s_str, " ]"};
        return s_str;
    endfunction

    // ========================================
    // External non-UVM method prototypes
    // ========================================
    extern function bit [7:0] compute_pec();
    extern function void      set_payload(bit [7:0] an_new_data[]);

endclass

// ========================================
// compute_pec
// ========================================
function bit [7:0] smbus_transaction::compute_pec();
    bit [7:0] n_crc;
    bit [7:0] n_addr_byte;
    bit [7:0] n_cur_byte;
    bit       n_msb;

    n_crc = 8'h00;
    n_addr_byte = {this.m_n_slave_addr, this.m_n_rw};

    // Address + R/W byte
    for (int i = 7; i >= 0; i--) begin
        n_msb = n_crc[7] ^ n_addr_byte[i];
        n_crc = {n_crc[6:0], 1'b0};
        if (n_msb) begin
            n_crc = n_crc ^ 8'h07;
        end
    end

    // Data bytes
    for (int b = 0; b < this.m_an_data.size(); b++) begin
        n_cur_byte = this.m_an_data[b];
        for (int i = 7; i >= 0; i--) begin
            n_msb = n_crc[7] ^ n_cur_byte[i];
            n_crc = {n_crc[6:0], 1'b0};
            if (n_msb) begin
                n_crc = n_crc ^ 8'h07;
            end
        end
    end

    return n_crc;
endfunction

// ========================================
// set_payload
// ========================================
function void smbus_transaction::set_payload(bit [7:0] an_new_data[]);
    this.m_an_data = new[an_new_data.size()];
    for (int i = 0; i < an_new_data.size(); i++) begin
        this.m_an_data[i] = an_new_data[i];
    end
    this.m_n_data_len = an_new_data.size();
    if (this.m_n_pec_enable) begin
        this.m_n_pec = this.compute_pec();
    end
endfunction

`endif // SMBUS_SEQ_ITEM_SV
