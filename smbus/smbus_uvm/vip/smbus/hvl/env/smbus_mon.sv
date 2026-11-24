`ifndef SMBUS_MON_SV
`define SMBUS_MON_SV

class smbus_mon extends uvm_monitor;

    typedef smbus_mon                                   t_smbus_mon;
    typedef smbus_transaction                           t_smbus_transaction;
    typedef virtual smbus_if                            t_smbus_vif;
    typedef uvm_analysis_port #(t_smbus_transaction)    t_smbus_ap;

    t_smbus_vif                                         m_st_vif;
    t_smbus_ap                                          m_st_ap;
    int                                                 m_n_collected_trans_count;
    bit                                                 m_n_pec_check_enable;
    bit                                                 m_n_pending_restart;

    `uvm_component_utils(smbus_mon)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_mon", uvm_component st_parent = null);
        super.new(s_name, st_parent);
        this.m_n_collected_trans_count = 0;
        this.m_n_pec_check_enable      = 1'b0;
        this.m_n_pending_restart       = 1'b0;
    endfunction

    // ========================================
    // build_phase
    // ========================================
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        this.m_st_ap = new("m_st_ap", this);
        if (!uvm_config_db#(virtual smbus_if)::get(this, "", "vif", this.m_st_vif)) begin
            `uvm_fatal("SMBUS_MON", "Virtual interface smbus_if not found in config_db")
        end
    endfunction

    // ========================================
    // run_phase
    // ========================================
    task run_phase(uvm_phase phase);
        @(posedge this.m_st_vif.rst_n);
        `uvm_info("SMBUS_MON", "SMBus Monitor started running", UVM_MEDIUM)

        forever begin
            this.monitor_bus();
        end
    endtask

    // ========================================
    // External non-UVM method prototypes
    // ========================================
    extern task monitor_bus();
    extern task wait_start_condition();
    extern task wait_stop_or_start_condition(output bit n_stop, output bit n_restart);
    extern task read_byte(output bit [7:0] n_byte);
    extern task sample_ack_bit(output bit n_ack);

endclass

// ========================================
// monitor_bus
// ========================================
task smbus_mon::monitor_bus();
    bit [7:0] n_addr_byte;
    bit [6:0] n_slave_addr;
    bit       n_rw;
    bit       n_addr_ack;
    bit [7:0] an_payload[$];
    bit [7:0] n_data_byte;
    bit       n_data_ack;
    bit       n_has_stop;
    bit       n_has_restart;
    smbus_transaction st_trans;

    // 1. Detect START condition (or proceed immediately if Repeated START was already detected)
    if (!this.m_n_pending_restart) begin
        this.wait_start_condition();
        `uvm_info("SMBUS_MON", "START condition detected", UVM_HIGH)
    end else begin
        this.m_n_pending_restart = 1'b0;
        `uvm_info("SMBUS_MON", "Repeated START condition detected", UVM_HIGH)
    end

    // 2. Read 7-bit Address + 1-bit R/W
    this.read_byte(n_addr_byte);
    n_slave_addr = n_addr_byte[7:1];
    n_rw         = n_addr_byte[0];

    // 3. Sample 9th clock ACK/NACK
    this.sample_ack_bit(n_addr_ack);

    // If NACK on address, package and finish transaction
    if (n_addr_ack == 1'b1) begin
        st_trans = smbus_transaction::type_id::create("st_trans");
        st_trans.m_n_slave_addr = n_slave_addr;
        st_trans.m_n_rw         = n_rw;
        st_trans.m_n_ack        = 1'b0;
        st_trans.m_n_nack       = 1'b1;
        st_trans.m_n_data_len   = 0;
        st_trans.m_an_data      = new[0];
        st_trans.m_n_start      = 1'b1;

        this.wait_stop_or_start_condition(n_has_stop, n_has_restart);
        st_trans.m_n_stop        = n_has_stop;
        st_trans.m_n_restart     = n_has_restart;
        this.m_n_pending_restart = n_has_restart;

        this.m_st_ap.write(st_trans);
        this.m_n_collected_trans_count++;
        return;
    end

    // 4. Address ACKed: collect data bytes until STOP or RESTART
    an_payload.delete();
    while (1) begin
        bit n_detected_stop;
        bit n_detected_restart;

        n_detected_stop    = 1'b0;
        n_detected_restart = 1'b0;

        // Wait for either next byte transmission or bus stop/restart
        fork
            begin : read_data
                this.read_byte(n_data_byte);
                this.sample_ack_bit(n_data_ack);
                an_payload.push_back(n_data_byte);
            end
            begin : detect_event
                this.wait_stop_or_start_condition(n_detected_stop, n_detected_restart);
            end
        join_any
        disable fork;

        if (n_detected_stop || n_detected_restart) begin
            n_has_stop               = n_detected_stop;
            n_has_restart            = n_detected_restart;
            this.m_n_pending_restart = n_detected_restart;
            break;
        end
    end

    // 5. Construct transaction and publish to analysis port
    st_trans = smbus_transaction::type_id::create("st_trans");
    st_trans.m_n_slave_addr = n_slave_addr;
    st_trans.m_n_rw         = n_rw;
    st_trans.m_n_ack        = 1'b1;
    st_trans.m_n_nack       = 1'b0;
    st_trans.m_n_start      = 1'b1;
    st_trans.m_n_stop       = n_has_stop;
    st_trans.m_n_restart    = n_has_restart;
    st_trans.m_n_data_len   = an_payload.size();

    st_trans.m_an_data = new[an_payload.size()];
    for (int i = 0; i < an_payload.size(); i++) begin
        st_trans.m_an_data[i] = an_payload[i];
    end

    `uvm_info("SMBUS_MON", $sformatf("Collected %s", st_trans.convert2string()), UVM_MEDIUM)
    this.m_st_ap.write(st_trans);
    this.m_n_collected_trans_count++;
endtask

// ========================================
// wait_start_condition
// ========================================
task smbus_mon::wait_start_condition();
    while (1) begin
        @(negedge this.m_st_vif.sda);
        if (this.m_st_vif.scl === 1'b1) begin
            break;
        end
    end
endtask

// ========================================
// wait_stop_or_start_condition
// ========================================
task smbus_mon::wait_stop_or_start_condition(output bit n_stop, output bit n_restart);
    n_stop    = 1'b0;
    n_restart = 1'b0;

    while (1) begin
        @(posedge this.m_st_vif.sda or negedge this.m_st_vif.sda);
        if (this.m_st_vif.scl === 1'b1) begin
            if (this.m_st_vif.sda === 1'b1) begin
                n_stop = 1'b1;
            end else begin
                n_restart = 1'b1;
            end
            break;
        end
    end
endtask

// ========================================
// read_byte
// ========================================
task smbus_mon::read_byte(output bit [7:0] n_byte);
    for (int i = 7; i >= 0; i--) begin
        @(posedge this.m_st_vif.scl);
        n_byte[i] = (this.m_st_vif.sda === 1'b1) ? 1'b1 : 1'b0;
    end
endtask

// ========================================
// sample_ack_bit
// ========================================
task smbus_mon::sample_ack_bit(output bit n_ack);
    @(posedge this.m_st_vif.scl);
    n_ack = (this.m_st_vif.sda === 1'b1) ? 1'b1 : 1'b0; // 0 = ACK, 1 = NACK
endtask

`endif // SMBUS_MON_SV
