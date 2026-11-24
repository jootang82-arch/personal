`ifndef SMBUS_SLAVE_DRV_SV
`define SMBUS_SLAVE_DRV_SV

class smbus_slave_drv extends uvm_driver #(smbus_transaction);

    typedef smbus_slave_drv                 t_smbus_slave_drv;
    typedef smbus_transaction               t_smbus_transaction;
    typedef virtual smbus_if                t_smbus_vif;

    t_smbus_vif                             m_st_vif;
    bit [6:0]                               m_n_slave_addr;
    bit                                     m_n_enable_ack;
    bit [7:0]                               m_an_mem [0:255];
    bit [7:0]                               m_n_ptr;
    int                                     m_n_stretch_cycles;
    int                                     m_n_rx_trans_count;
    int                                     m_n_tx_trans_count;
    bit                                     m_n_pending_restart;

    `uvm_component_utils(smbus_slave_drv)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_slave_drv", uvm_component st_parent = null);
        super.new(s_name, st_parent);
        this.m_n_slave_addr      = 7'h2A;
        this.m_n_enable_ack      = 1'b1;
        this.m_n_ptr             = 8'h00;
        this.m_n_stretch_cycles  = 0;
        this.m_n_rx_trans_count  = 0;
        this.m_n_tx_trans_count  = 0;
        this.m_n_pending_restart = 1'b0;
        for (int i = 0; i < 256; i++) begin
            this.m_an_mem[i] = 8'hA0 + i[7:0];
        end
    endfunction

    // ========================================
    // build_phase
    // ========================================
    function void build_phase(uvm_phase phase);
        int n_addr_cfg;
        super.build_phase(phase);
        if (!uvm_config_db#(virtual smbus_if)::get(this, "", "vif", this.m_st_vif)) begin
            `uvm_fatal("SMBUS_SDRV", "Virtual interface smbus_if not found in config_db")
        end
        if (uvm_config_db#(int)::get(this, "", "slave_addr", n_addr_cfg)) begin
            this.m_n_slave_addr = n_addr_cfg[6:0];
        end
    endfunction

    // ========================================
    // run_phase
    // ========================================
    task run_phase(uvm_phase phase);
        this.m_st_vif.slave_release_bus();
        @(posedge this.m_st_vif.rst_n);

        fork
            this.slave_listener_thread();
        join
    endtask

    // ========================================
    // External non-UVM method prototypes
    // ========================================
    extern task slave_listener_thread();
    extern task wait_start_condition();
    extern task wait_stop_or_restart_condition(output bit n_stop, output bit n_restart);
    extern task slave_read_byte(output bit [7:0] n_byte);
    extern task slave_send_byte(input bit [7:0] n_byte);
    extern task slave_send_ack();
    extern task slave_send_nack();
    extern task slave_sample_master_ack(output bit n_ack);

endclass

// ========================================
// slave_listener_thread
// ========================================
task smbus_slave_drv::slave_listener_thread();
    bit [7:0] n_rx_byte;
    bit       n_rw;
    bit [6:0] n_rx_addr;
    bit       n_master_ack;
    smbus_transaction st_resp;

    forever begin
        if (!this.m_n_pending_restart) begin
            this.wait_start_condition();
            `uvm_info("SMBUS_SDRV", "START condition detected", UVM_HIGH)
        end else begin
            this.m_n_pending_restart = 1'b0;
            `uvm_info("SMBUS_SDRV", "Repeated START condition detected", UVM_HIGH)
        end

        // Receive Address (7 bits) + RW bit (1 bit)
        this.slave_read_byte(n_rx_byte);
        n_rx_addr = n_rx_byte[7:1];
        n_rw      = n_rx_byte[0];

        if (n_rx_addr !== this.m_n_slave_addr || !this.m_n_enable_ack) begin
            `uvm_info("SMBUS_SDRV", $sformatf("Address mismatch/disabled: expected 0x%02h, got 0x%02h. NACKing.",
                      this.m_n_slave_addr, n_rx_addr), UVM_HIGH)
            this.slave_send_nack();
            continue;
        end

        // Check if sequence provided specific response transaction
        st_resp = null;
        if (this.seq_item_port.has_do_available()) begin
            this.seq_item_port.try_next_item(st_resp);
        end

        // Send ACK for address
        this.slave_send_ack();

        // Write Operation: Master transmits, Slave receives
        if (n_rw == 1'b0) begin
            bit n_is_first;
            n_is_first = 1'b1;

            while (1) begin
                bit n_detected_stop;
                bit n_detected_restart;
                n_detected_stop    = 1'b0;
                n_detected_restart = 1'b0;

                fork
                    begin : wait_byte
                        this.slave_read_byte(n_rx_byte);
                    end
                    begin : wait_stop_or_restart
                        this.wait_stop_or_restart_condition(n_detected_stop, n_detected_restart);
                    end
                join_any
                disable fork;

                if (n_detected_stop) begin
                    `uvm_info("SMBUS_SDRV", "STOP condition detected during write", UVM_HIGH)
                    break;
                end

                if (n_detected_restart) begin
                    `uvm_info("SMBUS_SDRV", "Repeated START detected during write", UVM_HIGH)
                    this.m_n_pending_restart = 1'b1;
                    break;
                end

                this.slave_send_ack();
                if (n_is_first) begin
                    this.m_n_ptr = n_rx_byte;
                    n_is_first   = 1'b0;
                end else begin
                    this.m_an_mem[this.m_n_ptr] = n_rx_byte;
                    this.m_n_ptr++;
                end
            end
            this.m_n_rx_trans_count++;
        end
        // Read Operation: Slave transmits, Master receives
        else begin
            while (1) begin
                bit [7:0] n_tx_byte;
                n_tx_byte = this.m_an_mem[this.m_n_ptr];
                this.slave_send_byte(n_tx_byte);
                this.m_n_ptr++;

                // Sample Master ACK / NACK
                this.slave_sample_master_ack(n_master_ack);
                if (n_master_ack == 1'b1) begin
                    `uvm_info("SMBUS_SDRV", "Master NACK received - Read cycle completed", UVM_HIGH)
                    break;
                end
            end
            this.m_n_tx_trans_count++;
        end

        if (st_resp != null) begin
            this.seq_item_port.item_done();
            st_resp = null;
        end
    end
endtask

// ========================================
// wait_start_condition
// ========================================
task smbus_slave_drv::wait_start_condition();
    while (1) begin
        @(negedge this.m_st_vif.sda);
        if (this.m_st_vif.scl === 1'b1) begin
            break;
        end
    end
endtask

// ========================================
// wait_stop_or_restart_condition
// ========================================
task smbus_slave_drv::wait_stop_or_restart_condition(output bit n_stop, output bit n_restart);
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
// slave_read_byte
// ========================================
task smbus_slave_drv::slave_read_byte(output bit [7:0] n_byte);
    this.m_st_vif.slave_release_sda();
    for (int i = 7; i >= 0; i--) begin
        @(posedge this.m_st_vif.scl);
        n_byte[i] = (this.m_st_vif.sda === 1'b1) ? 1'b1 : 1'b0;
    end
endtask

// ========================================
// slave_send_byte
// ========================================
task smbus_slave_drv::slave_send_byte(input bit [7:0] n_byte);
    for (int i = 7; i >= 0; i--) begin
        if (n_byte[i] == 1'b0) begin
            this.m_st_vif.slave_drive_sda_low();
        end else begin
            this.m_st_vif.slave_release_sda();
        end
        @(negedge this.m_st_vif.scl);
    end
    this.m_st_vif.slave_release_sda();
endtask

// ========================================
// slave_send_ack
// ========================================
task smbus_slave_drv::slave_send_ack();
    @(negedge this.m_st_vif.scl);
    this.m_st_vif.slave_drive_sda_low();
    @(negedge this.m_st_vif.scl);
    this.m_st_vif.slave_release_sda();
endtask

// ========================================
// slave_send_nack
// ========================================
task smbus_slave_drv::slave_send_nack();
    @(negedge this.m_st_vif.scl);
    this.m_st_vif.slave_release_sda();
    @(negedge this.m_st_vif.scl);
endtask

// ========================================
// slave_sample_master_ack
// ========================================
task smbus_slave_drv::slave_sample_master_ack(output bit n_ack);
    this.m_st_vif.slave_release_sda();
    @(posedge this.m_st_vif.scl);
    n_ack = (this.m_st_vif.sda === 1'b1) ? 1'b1 : 1'b0;
    @(negedge this.m_st_vif.scl);
endtask

`endif // SMBUS_SLAVE_DRV_SV
