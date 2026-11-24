`ifndef SMBUS_MASTER_DRV_SV
`define SMBUS_MASTER_DRV_SV

class smbus_master_drv extends uvm_driver #(smbus_transaction);

    typedef smbus_master_drv                t_smbus_master_drv;
    typedef smbus_transaction               t_smbus_transaction;
    typedef virtual smbus_if                t_smbus_vif;

    t_smbus_vif                             m_st_vif;
    int                                     m_n_t_half_clk_ns;
    int                                     m_n_bus_free_extra_ns;
    int                                     m_n_timeout_limit_ns;
    int                                     m_n_trans_count;
    int                                     m_n_arb_loss_count;
    int                                     m_n_max_arb_retries;
    bit                                     m_n_in_progress;
    bit                                     m_n_arb_lost;

    `uvm_component_utils(smbus_master_drv)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_master_drv", uvm_component st_parent = null);
        super.new(s_name, st_parent);
        this.m_n_t_half_clk_ns     = 250;   // 500ns SCL period
        this.m_n_bus_free_extra_ns = 0;     // Optional extra bus-free guard time
        this.m_n_timeout_limit_ns  = 50000; // 50us timeout limit
        this.m_n_trans_count       = 0;
        this.m_n_arb_loss_count    = 0;
        this.m_n_max_arb_retries   = 16;
        this.m_n_in_progress       = 1'b0;
        this.m_n_arb_lost          = 1'b0;
    endfunction

    // ========================================
    // build_phase
    // ========================================
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(virtual smbus_if)::get(this, "", "vif", this.m_st_vif)) begin
            `uvm_fatal("SMBUS_MDRV", "Virtual interface smbus_if not found in config_db")
        end
        void'(uvm_config_db#(int)::get(this, "", "bus_free_extra_ns", this.m_n_bus_free_extra_ns));
    endfunction

    // ========================================
    // run_phase
    // ========================================
    task run_phase(uvm_phase phase);
        smbus_transaction st_req;

        this.drive_idle();
        @(posedge this.m_st_vif.rst_n);
        #(this.m_n_t_half_clk_ns * 2);

        forever begin
            this.seq_item_port.get_next_item(st_req);
            this.m_n_in_progress = 1'b1;
            this.drive_transaction(st_req);
            this.m_n_trans_count++;
            this.m_n_in_progress = 1'b0;
            this.seq_item_port.item_done();
        end
    endtask

    // ========================================
    // External non-UVM method prototypes
    // ========================================
    extern task drive_idle();
    extern task wait_bus_free();
    extern task drive_start(output bit n_ok);
    extern task drive_restart();
    extern task drive_stop();
    extern task wait_scl_high();
    extern task send_byte(input bit [7:0] n_byte, output bit n_ack, output bit n_arb_lost);
    extern task recv_byte(input bit n_ack_to_send, output bit [7:0] n_byte);
    extern task drive_transaction(smbus_transaction st_trans);

endclass

// ========================================
// drive_idle
// ========================================
task smbus_master_drv::drive_idle();
    this.m_st_vif.master_release_bus();
    #(this.m_n_t_half_clk_ns * 2);
endtask

// ========================================
// wait_bus_free
// ========================================
task smbus_master_drv::wait_bus_free();
    int n_idle_ns;
    int n_required_idle_ns;

    n_required_idle_ns = (this.m_n_t_half_clk_ns * 2) + this.m_n_bus_free_extra_ns;
    n_idle_ns = 0;

    while (n_idle_ns < n_required_idle_ns) begin
        if (this.m_st_vif.bus_busy === 1'b0 &&
            this.m_st_vif.scl      === 1'b1 &&
            this.m_st_vif.sda      === 1'b1) begin
            #25;
            n_idle_ns += 25;
        end else begin
            n_idle_ns = 0;
            #25;
        end
    end
endtask

// ========================================
// drive_start
// ========================================
task smbus_master_drv::drive_start(output bit n_ok);
    n_ok = 1'b0;
    this.m_st_vif.master_release_bus();
    this.wait_bus_free();

    // Check if bus was claimed just before START
    if (this.m_st_vif.scl !== 1'b1 || this.m_st_vif.sda !== 1'b1) begin
        n_ok = 1'b0;
        return;
    end

    this.m_st_vif.master_drive_sda_low();
    #(this.m_n_t_half_clk_ns);
    this.m_st_vif.master_drive_scl_low();
    #(this.m_n_t_half_clk_ns);
    n_ok = 1'b1;
endtask

// ========================================
// drive_restart
// ========================================
task smbus_master_drv::drive_restart();
    this.m_st_vif.master_drive_scl_low();
    #10;
    this.m_st_vif.master_release_sda();
    #(this.m_n_t_half_clk_ns);
    this.wait_scl_high();
    #(this.m_n_t_half_clk_ns);
    this.m_st_vif.master_drive_sda_low();
    #(this.m_n_t_half_clk_ns);
    this.m_st_vif.master_drive_scl_low();
    #(this.m_n_t_half_clk_ns);
endtask

// ========================================
// drive_stop
// ========================================
task smbus_master_drv::drive_stop();
    this.m_st_vif.master_drive_scl_low();
    #10;
    this.m_st_vif.master_drive_sda_low();
    #(this.m_n_t_half_clk_ns);
    this.wait_scl_high();
    #(this.m_n_t_half_clk_ns);
    this.m_st_vif.master_release_sda();
    #(this.m_n_t_half_clk_ns * 2);
endtask

// ========================================
// wait_scl_high
// ========================================
task smbus_master_drv::wait_scl_high();
    int n_waited_ns;
    n_waited_ns = 0;
    this.m_st_vif.master_release_scl();

    while (this.m_st_vif.scl !== 1'b1) begin
        #10;
        n_waited_ns += 10;
        if (n_waited_ns >= this.m_n_timeout_limit_ns) begin
            `uvm_error("SMBUS_MDRV", "SCL Clock stretching timeout detected!")
            break;
        end
    end
endtask

// ========================================
// send_byte
// ========================================
task smbus_master_drv::send_byte(input bit [7:0] n_byte, output bit n_ack, output bit n_arb_lost);
    n_ack      = 1'b1;
    n_arb_lost = 1'b0;

    for (int i = 7; i >= 0; i--) begin
        if (n_byte[i] == 1'b0) begin
            this.m_st_vif.master_drive_sda_low();
        end else begin
            this.m_st_vif.master_release_sda();
        end
        #(this.m_n_t_half_clk_ns);
        this.wait_scl_high();

        // Standard SMBus/I2C open-drain arbitration check
        if (n_byte[i] == 1'b1 && this.m_st_vif.sda === 1'b0) begin
            n_arb_lost = 1'b1;
            this.m_n_arb_lost = 1'b1;
            this.m_n_arb_loss_count++;
            this.m_st_vif.master_release_bus();
            `uvm_info("SMBUS_MDRV", $sformatf("[%s] Arbitration lost at bit %0d of byte 0x%02h",
                      this.get_full_name(), i, n_byte), UVM_MEDIUM)
            return;
        end

        #(this.m_n_t_half_clk_ns);
        this.m_st_vif.master_drive_scl_low();
        #10; // Hold time before changing SDA for next bit
    end

    // 9th clock cycle: ACK / NACK sample
    this.m_st_vif.master_release_sda();
    #(this.m_n_t_half_clk_ns);
    this.wait_scl_high();
    n_ack = this.m_st_vif.sda;
    #(this.m_n_t_half_clk_ns);
    this.m_st_vif.master_drive_scl_low();
    #(this.m_n_t_half_clk_ns);
endtask

// ========================================
// recv_byte
// ========================================
task smbus_master_drv::recv_byte(input bit n_ack_to_send, output bit [7:0] n_byte);
    this.m_st_vif.master_release_sda();

    for (int i = 7; i >= 0; i--) begin
        #(this.m_n_t_half_clk_ns);
        this.wait_scl_high();
        n_byte[i] = (this.m_st_vif.sda === 1'b1) ? 1'b1 : 1'b0;
        #(this.m_n_t_half_clk_ns);
        this.m_st_vif.master_drive_scl_low();
        #10;
    end

    // 9th clock cycle: drive ACK or NACK
    if (n_ack_to_send == 1'b0) begin
        this.m_st_vif.master_drive_sda_low(); // ACK
    end else begin
        this.m_st_vif.master_release_sda();   // NACK
    end
    #(this.m_n_t_half_clk_ns);
    this.wait_scl_high();
    #(this.m_n_t_half_clk_ns);
    this.m_st_vif.master_drive_scl_low();
    #10;
    this.m_st_vif.master_release_sda();
    #(this.m_n_t_half_clk_ns);
endtask

// ========================================
// drive_transaction
// ========================================
task smbus_master_drv::drive_transaction(smbus_transaction st_trans);
    bit [7:0] n_addr_byte;
    bit       n_ack;
    bit       n_arb_lost;
    bit       n_start_ok;
    bit [7:0] n_rx_byte;
    int       n_retry;

    n_addr_byte = {st_trans.m_n_slave_addr, st_trans.m_n_rw};

    for (n_retry = 0; n_retry <= this.m_n_max_arb_retries; n_retry++) begin
        this.m_n_arb_lost = 1'b0;
        n_arb_lost        = 1'b0;

        // Bus condition: START or RESTART
        if (st_trans.m_n_restart) begin
            this.drive_restart();
        end else if (st_trans.m_n_start) begin
            this.drive_start(n_start_ok);
            if (!n_start_ok) begin
                this.m_n_arb_loss_count++;
                continue;
            end
        end

        // Send Slave Address + RW bit
        this.send_byte(n_addr_byte, n_ack, n_arb_lost);
        if (n_arb_lost) begin
            continue;
        end

        st_trans.m_n_ack  = (n_ack == 1'b0);
        st_trans.m_n_nack = (n_ack == 1'b1);

        if (n_ack == 1'b1) begin
            `uvm_info("SMBUS_MDRV", $sformatf("NACK received for address 0x%02h",
                      st_trans.m_n_slave_addr), UVM_HIGH)
            if (st_trans.m_n_stop) begin
                this.drive_stop();
            end
            return;
        end

        // Handle Write transfer
        if (st_trans.m_n_rw == 1'b0) begin
            for (int i = 0; i < st_trans.m_an_data.size(); i++) begin
                this.send_byte(st_trans.m_an_data[i], n_ack, n_arb_lost);
                if (n_arb_lost) begin
                    break;
                end
                if (n_ack == 1'b1) begin
                    `uvm_warning("SMBUS_MDRV", $sformatf("Data byte %0d NACKed by slave", i))
                    break;
                end
            end
            if (n_arb_lost) begin
                continue;
            end
            // Send PEC byte if enabled
            if (st_trans.m_n_pec_enable) begin
                this.send_byte(st_trans.m_n_pec, n_ack, n_arb_lost);
                if (n_arb_lost) begin
                    continue;
                end
            end
        end
        // Handle Read transfer
        else begin
            bit [7:0] an_rx_data[];
            int n_total_bytes;
            n_total_bytes = st_trans.m_n_data_len;
            if (n_total_bytes == 0) n_total_bytes = 1;
            an_rx_data = new[n_total_bytes];

            for (int i = 0; i < n_total_bytes; i++) begin
                bit n_ack_val;
                // SMBus rule: Master NACKs the last byte before STOP
                n_ack_val = (i == (n_total_bytes - 1) && !st_trans.m_n_pec_enable) ? 1'b1 : 1'b0;
                this.recv_byte(n_ack_val, n_rx_byte);
                an_rx_data[i] = n_rx_byte;
            end
            st_trans.m_an_data = an_rx_data;

            if (st_trans.m_n_pec_enable) begin
                this.recv_byte(1'b1, n_rx_byte); // NACK PEC byte
                st_trans.m_n_pec = n_rx_byte;
            end
        end

        // STOP condition
        if (st_trans.m_n_stop) begin
            this.drive_stop();
        end
        return;
    end

    `uvm_error("SMBUS_MDRV", $sformatf("Exceeded max arbitration retries (%0d) for addr 0x%02h",
               this.m_n_max_arb_retries, st_trans.m_n_slave_addr))
endtask

`endif // SMBUS_MASTER_DRV_SV
