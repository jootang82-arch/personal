`ifndef SMBUS_IP_BASE_SEQUENCE_SV
`define SMBUS_IP_BASE_SEQUENCE_SV

class smbus_ip_base_sequence extends uvm_sequence #(smbus_transaction);

    typedef smbus_ip_base_sequence          t_smbus_ip_base_sequence;
    typedef smbus_master_sqr                t_smbus_master_sqr;
    typedef smbus_slave_sqr                 t_smbus_slave_sqr;
    typedef smbus_transaction               t_smbus_transaction;

    static t_smbus_master_sqr               m_st_master_sqr;
    static t_smbus_slave_sqr                m_st_slave_sqr;

    `uvm_object_utils(smbus_ip_base_sequence)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_ip_base_sequence");
        super.new(s_name);
    endfunction

    // ========================================
    // pre_body
    // ========================================
    task pre_body();
        if (this.starting_phase != null) begin
            this.starting_phase.raise_objection(this, {"Running sequence ", this.get_name()});
        end
    endtask

    // ========================================
    // post_body
    // ========================================
    task post_body();
        if (this.starting_phase != null) begin
            this.starting_phase.drop_objection(this, {"Completed sequence ", this.get_name()});
        end
    endtask

endclass

// TC001: Reset Sequence
class smbus_ip_reset_seq extends smbus_ip_base_sequence;

    typedef smbus_ip_reset_seq              t_smbus_ip_reset_seq;

    `uvm_object_utils(smbus_ip_reset_seq)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_ip_reset_seq");
        super.new(s_name);
    endfunction

    // ========================================
    // body
    // ========================================
    task body();
        `uvm_info("SEQ_RESET", "Executing SMBus Reset Verification Sequence", UVM_LOW)
        #200; // Allow reset propagation and observe idle bus
    endtask

endclass

// TC002: Idle Sequence
class smbus_ip_idle_seq extends smbus_ip_base_sequence;

    typedef smbus_ip_idle_seq               t_smbus_ip_idle_seq;

    `uvm_object_utils(smbus_ip_idle_seq)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_ip_idle_seq");
        super.new(s_name);
    endfunction

    // ========================================
    // body
    // ========================================
    task body();
        `uvm_info("SEQ_IDLE", "Executing SMBus Idle Bus Verification Sequence", UVM_LOW)
        #1000;
    endtask

endclass

// TC003: Start/Stop Sequence
class smbus_ip_start_stop_seq extends smbus_ip_base_sequence;

    typedef smbus_ip_start_stop_seq         t_smbus_ip_start_stop_seq;

    `uvm_object_utils(smbus_ip_start_stop_seq)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_ip_start_stop_seq");
        super.new(s_name);
    endfunction

    // ========================================
    // body
    // ========================================
    task body();
        smbus_transaction st_tr;
        `uvm_info("SEQ_START_STOP", "Executing SMBus START/STOP Verification Sequence", UVM_LOW)

        st_tr = smbus_transaction::type_id::create("st_tr");
        this.start_item(st_tr, -1, this.m_st_master_sqr);
        st_tr.m_n_slave_addr = 7'h2A;
        st_tr.m_n_rw         = 1'b0;
        st_tr.m_n_data_len   = 0;
        st_tr.m_an_data      = new[0];
        st_tr.m_n_start      = 1'b1;
        st_tr.m_n_stop       = 1'b1;
        this.finish_item(st_tr);
    endtask

endclass

// TC004: Write Sequence
class smbus_ip_write_seq extends smbus_ip_base_sequence;

    typedef smbus_ip_write_seq              t_smbus_ip_write_seq;

    rand bit [6:0]                          m_n_slave_addr;
    rand bit [7:0]                          m_n_reg_addr;
    rand bit [7:0]                          m_n_write_data;

    `uvm_object_utils(smbus_ip_write_seq)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_ip_write_seq");
        super.new(s_name);
        this.m_n_slave_addr = 7'h2A;
        this.m_n_reg_addr   = 8'h10;
        this.m_n_write_data = 8'hBE;
    endfunction

    // ========================================
    // body
    // ========================================
    task body();
        smbus_transaction st_tr;
        `uvm_info("SEQ_WRITE", $sformatf("Executing Master Write: Addr=0x%02h Reg=0x%02h Data=0x%02h",
                  this.m_n_slave_addr, this.m_n_reg_addr, this.m_n_write_data), UVM_LOW)

        st_tr = smbus_transaction::type_id::create("st_tr");
        this.start_item(st_tr, -1, this.m_st_master_sqr);
        st_tr.m_n_slave_addr = this.m_n_slave_addr;
        st_tr.m_n_rw         = 1'b0;
        st_tr.m_n_data_len   = 2;
        st_tr.m_an_data      = new[2];
        st_tr.m_an_data[0]   = this.m_n_reg_addr;
        st_tr.m_an_data[1]   = this.m_n_write_data;
        st_tr.m_n_start      = 1'b1;
        st_tr.m_n_stop       = 1'b1;
        this.finish_item(st_tr);
    endtask

endclass

// TC005: Read Sequence
class smbus_ip_read_seq extends smbus_ip_base_sequence;

    typedef smbus_ip_read_seq               t_smbus_ip_read_seq;

    rand bit [6:0]                          m_n_slave_addr;
    rand bit [7:0]                          m_n_reg_addr;

    `uvm_object_utils(smbus_ip_read_seq)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_ip_read_seq");
        super.new(s_name);
        this.m_n_slave_addr = 7'h2A;
        this.m_n_reg_addr   = 8'h05;
    endfunction

    // ========================================
    // body
    // ========================================
    task body();
        smbus_transaction st_wr;
        smbus_transaction st_rd;
        `uvm_info("SEQ_READ", $sformatf("Executing Master Read: Addr=0x%02h Reg=0x%02h",
                  this.m_n_slave_addr, this.m_n_reg_addr), UVM_LOW)

        // Step 1: Write pointer register address
        st_wr = smbus_transaction::type_id::create("st_wr");
        this.start_item(st_wr, -1, this.m_st_master_sqr);
        st_wr.m_n_slave_addr = this.m_n_slave_addr;
        st_wr.m_n_rw         = 1'b0;
        st_wr.m_n_data_len   = 1;
        st_wr.m_an_data      = new[1];
        st_wr.m_an_data[0]   = this.m_n_reg_addr;
        st_wr.m_n_start      = 1'b1;
        st_wr.m_n_stop       = 1'b0; // Repeated start follow-up
        this.finish_item(st_wr);

        // Step 2: Read data from slave
        st_rd = smbus_transaction::type_id::create("st_rd");
        this.start_item(st_rd, -1, this.m_st_master_sqr);
        st_rd.m_n_slave_addr = this.m_n_slave_addr;
        st_rd.m_n_rw         = 1'b1;
        st_rd.m_n_data_len   = 1;
        st_rd.m_n_start      = 1'b1;
        st_rd.m_n_restart    = 1'b1;
        st_rd.m_n_stop       = 1'b1;
        this.finish_item(st_rd);
    endtask

endclass

// TC006: ACK Sequence
class smbus_ip_ack_seq extends smbus_ip_base_sequence;

    typedef smbus_ip_ack_seq                t_smbus_ip_ack_seq;

    `uvm_object_utils(smbus_ip_ack_seq)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_ip_ack_seq");
        super.new(s_name);
    endfunction

    // ========================================
    // body
    // ========================================
    task body();
        smbus_transaction st_tr;
        `uvm_info("SEQ_ACK", "Executing Address ACK Verification Sequence", UVM_LOW)

        st_tr = smbus_transaction::type_id::create("st_tr");
        this.start_item(st_tr, -1, this.m_st_master_sqr);
        st_tr.m_n_slave_addr = 7'h2A; // Valid matching address
        st_tr.m_n_rw         = 1'b0;
        st_tr.m_n_data_len   = 1;
        st_tr.m_an_data      = new[1];
        st_tr.m_an_data[0]   = 8'hAA;
        st_tr.m_n_start      = 1'b1;
        st_tr.m_n_stop       = 1'b1;
        this.finish_item(st_tr);
    endtask

endclass

// TC007: NACK Sequence
class smbus_ip_nack_seq extends smbus_ip_base_sequence;

    typedef smbus_ip_nack_seq               t_smbus_ip_nack_seq;

    `uvm_object_utils(smbus_ip_nack_seq)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_ip_nack_seq");
        super.new(s_name);
    endfunction

    // ========================================
    // body
    // ========================================
    task body();
        smbus_transaction st_tr;
        `uvm_info("SEQ_NACK", "Executing Address NACK Verification Sequence", UVM_LOW)

        st_tr = smbus_transaction::type_id::create("st_tr");
        this.start_item(st_tr, -1, this.m_st_master_sqr);
        st_tr.m_n_slave_addr = 7'h55; // Non-existent address -> expectation: NACK
        st_tr.m_n_rw         = 1'b0;
        st_tr.m_n_data_len   = 1;
        st_tr.m_an_data      = new[1];
        st_tr.m_an_data[0]   = 8'h00;
        st_tr.m_n_start      = 1'b1;
        st_tr.m_n_stop       = 1'b1;
        this.finish_item(st_tr);
    endtask

endclass

// TC008: Multi-byte Sequence
class smbus_ip_multi_byte_seq extends smbus_ip_base_sequence;

    typedef smbus_ip_multi_byte_seq         t_smbus_ip_multi_byte_seq;

    `uvm_object_utils(smbus_ip_multi_byte_seq)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_ip_multi_byte_seq");
        super.new(s_name);
    endfunction

    // ========================================
    // body
    // ========================================
    task body();
        smbus_transaction st_tr;
        `uvm_info("SEQ_MULTI", "Executing Multi-byte Transfer Verification Sequence", UVM_LOW)

        st_tr = smbus_transaction::type_id::create("st_tr");
        this.start_item(st_tr, -1, this.m_st_master_sqr);
        st_tr.m_n_slave_addr = 7'h2A;
        st_tr.m_n_rw         = 1'b0;
        st_tr.m_n_data_len   = 5;
        st_tr.m_an_data      = new[5];
        st_tr.m_an_data[0]   = 8'h20; // Reg start address
        st_tr.m_an_data[1]   = 8'hDE; // Data 0
        st_tr.m_an_data[2]   = 8'hAD; // Data 1
        st_tr.m_an_data[3]   = 8'hBE; // Data 2
        st_tr.m_an_data[4]   = 8'hEF; // Data 3
        st_tr.m_n_start      = 1'b1;
        st_tr.m_n_stop       = 1'b1;
        this.finish_item(st_tr);
    endtask

endclass

// TC009: Restart Sequence
class smbus_ip_restart_seq extends smbus_ip_base_sequence;

    typedef smbus_ip_restart_seq            t_smbus_ip_restart_seq;

    `uvm_object_utils(smbus_ip_restart_seq)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_ip_restart_seq");
        super.new(s_name);
    endfunction

    // ========================================
    // body
    // ========================================
    task body();
        smbus_transaction st_wr;
        smbus_transaction st_rd;
        `uvm_info("SEQ_RESTART", "Executing Repeated START Verification Sequence", UVM_LOW)

        // Write address pointer
        st_wr = smbus_transaction::type_id::create("st_wr");
        this.start_item(st_wr, -1, this.m_st_master_sqr);
        st_wr.m_n_slave_addr = 7'h2A;
        st_wr.m_n_rw         = 1'b0;
        st_wr.m_n_data_len   = 2;
        st_wr.m_an_data      = new[2];
        st_wr.m_an_data[0]   = 8'h30;
        st_wr.m_an_data[1]   = 8'h77;
        st_wr.m_n_start      = 1'b1;
        st_wr.m_n_stop       = 1'b0; // Repeated START without STOP
        this.finish_item(st_wr);

        // Immediate Read via Repeated START
        st_rd = smbus_transaction::type_id::create("st_rd");
        this.start_item(st_rd, -1, this.m_st_master_sqr);
        st_rd.m_n_slave_addr = 7'h2A;
        st_rd.m_n_rw         = 1'b1;
        st_rd.m_n_data_len   = 1;
        st_rd.m_n_start      = 1'b1;
        st_rd.m_n_restart    = 1'b1;
        st_rd.m_n_stop       = 1'b1;
        this.finish_item(st_rd);
    endtask

endclass

// TC010: Random Sequence
class smbus_ip_random_seq extends smbus_ip_base_sequence;

    typedef smbus_ip_random_seq             t_smbus_ip_random_seq;

    rand int                                m_n_num_trans;

    constraint c_num_trans {
        m_n_num_trans inside {[5:10]};
    }

    `uvm_object_utils(smbus_ip_random_seq)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_ip_random_seq");
        super.new(s_name);
        this.m_n_num_trans = 5;
    endfunction

    // ========================================
    // body
    // ========================================
    task body();
        smbus_transaction st_tr;
        `uvm_info("SEQ_RANDOM", $sformatf("Executing Random Verification Sequence with %0d transactions",
                  this.m_n_num_trans), UVM_LOW)

        for (int i = 0; i < this.m_n_num_trans; i++) begin
            st_tr = smbus_transaction::type_id::create($sformatf("st_tr_%0d", i));
            this.start_item(st_tr, -1, this.m_st_master_sqr);
            if (!st_tr.randomize()) begin
                `uvm_fatal("SEQ_RANDOM", "Transaction randomization failed")
            end
            st_tr.m_n_slave_addr = 7'h2A;
            st_tr.m_n_stop       = 1'b1;
            st_tr.m_n_restart    = 1'b0;
            this.finish_item(st_tr);
        end
    endtask

endclass

// Slave Responder Sequence
class smbus_ip_slave_response_seq extends smbus_ip_base_sequence;

    typedef smbus_ip_slave_response_seq     t_smbus_ip_slave_response_seq;

    `uvm_object_utils(smbus_ip_slave_response_seq)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_ip_slave_response_seq");
        super.new(s_name);
    endfunction

    // ========================================
    // body
    // ========================================
    task body();
        smbus_transaction st_resp;
        st_resp = smbus_transaction::type_id::create("st_resp");
        this.start_item(st_resp, -1, this.m_st_slave_sqr);
        st_resp.m_n_slave_addr = 7'h2A;
        st_resp.m_n_ack        = 1'b1;
        this.finish_item(st_resp);
    endtask

endclass

// Multi-Topology Master Worker Sequence (supports 1:1, N:1, N:N)
class smbus_ip_master_worker_seq extends smbus_ip_base_sequence;

    typedef smbus_ip_master_worker_seq      t_smbus_ip_master_worker_seq;

    int                                     m_n_master_id;
    int                                     m_n_ops_per_slave;
    bit                                     m_n_check_nack;
    bit [6:0]                               m_an_target_addrs[];

    `uvm_object_utils(smbus_ip_master_worker_seq)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_ip_master_worker_seq");
        super.new(s_name);
        this.m_n_master_id     = 0;
        this.m_n_ops_per_slave = 2;
        this.m_n_check_nack    = 1'b0;
        this.m_an_target_addrs = new[1];
        this.m_an_target_addrs[0] = 7'h2A;
    endfunction

    // ========================================
    // body
    // ========================================
    task body();
        smbus_transaction st_wr;
        smbus_transaction st_ptr;
        smbus_transaction st_rd;
        smbus_transaction st_burst;
        smbus_transaction st_nack;
        bit [6:0]         n_addr;
        bit [7:0]         n_reg;
        bit [7:0]         n_val;
        bit [7:0]         n_burst_reg;

        `uvm_info("SEQ_TOPO", $sformatf("[M%0d] Starting worker sequence for %0d slave(s), %0d op(s)/slave",
                  this.m_n_master_id, this.m_an_target_addrs.size(), this.m_n_ops_per_slave), UVM_LOW)

        for (int s = 0; s < this.m_an_target_addrs.size(); s++) begin
            n_addr = this.m_an_target_addrs[s];

            // 1. Disjoint single-byte Write + Repeated-START Readback per (Master, Slave, Op)
            for (int op = 0; op < this.m_n_ops_per_slave; op++) begin
                // Non-overlapping register window per master: M0=0x10.., M1=0x30.., M2=0x50.., M3=0x70..
                n_reg = 8'h10 + (this.m_n_master_id[7:0] * 8'h20) + op[7:0];
                n_val = 8'hC0 ^ {this.m_n_master_id[3:0], s[3:0]} ^ op[7:0];

                // Write [reg, val]
                st_wr = smbus_transaction::type_id::create($sformatf("st_wr_m%0d_s%0d_op%0d", this.m_n_master_id, s, op));
                this.start_item(st_wr);
                st_wr.m_n_slave_addr = n_addr;
                st_wr.m_n_rw         = 1'b0;
                st_wr.m_n_data_len   = 2;
                st_wr.m_an_data      = new[2];
                st_wr.m_an_data[0]   = n_reg;
                st_wr.m_an_data[1]   = n_val;
                st_wr.m_n_start      = 1'b1;
                st_wr.m_n_restart    = 1'b0;
                st_wr.m_n_stop       = 1'b1;
                this.finish_item(st_wr);

                // Pointer Write (STOP=0) + Repeated START Read (STOP=1)
                st_ptr = smbus_transaction::type_id::create($sformatf("st_ptr_m%0d_s%0d_op%0d", this.m_n_master_id, s, op));
                this.start_item(st_ptr);
                st_ptr.m_n_slave_addr = n_addr;
                st_ptr.m_n_rw         = 1'b0;
                st_ptr.m_n_data_len   = 1;
                st_ptr.m_an_data      = new[1];
                st_ptr.m_an_data[0]   = n_reg;
                st_ptr.m_n_start      = 1'b1;
                st_ptr.m_n_restart    = 1'b0;
                st_ptr.m_n_stop       = 1'b0;
                this.finish_item(st_ptr);

                st_rd = smbus_transaction::type_id::create($sformatf("st_rd_m%0d_s%0d_op%0d", this.m_n_master_id, s, op));
                this.start_item(st_rd);
                st_rd.m_n_slave_addr = n_addr;
                st_rd.m_n_rw         = 1'b1;
                st_rd.m_n_data_len   = 1;
                st_rd.m_n_start      = 1'b1;
                st_rd.m_n_restart    = 1'b1;
                st_rd.m_n_stop       = 1'b1;
                this.finish_item(st_rd);

                if (st_rd.m_an_data.size() < 1 || st_rd.m_an_data[0] !== n_val) begin
                    `uvm_error("SEQ_TOPO", $sformatf("[M%0d->S%0d@0x%02h] Readback mismatch at reg 0x%02h: exp=0x%02h act=0x%02h",
                               this.m_n_master_id, s, n_addr, n_reg, n_val,
                               (st_rd.m_an_data.size() > 0 ? st_rd.m_an_data[0] : 8'h00)))
                end else begin
                    `uvm_info("SEQ_TOPO", $sformatf("[M%0d->S%0d@0x%02h] PASS Write/Readback reg[0x%02h]=0x%02h",
                              this.m_n_master_id, s, n_addr, n_reg, n_val), UVM_MEDIUM)
                end
            end

            // 2. Multi-byte Burst Write (3 data bytes) + Repeated-START Multi-byte Readback
            n_burst_reg = 8'h18 + (this.m_n_master_id[7:0] * 8'h20);
            st_burst = smbus_transaction::type_id::create($sformatf("st_burst_m%0d_s%0d", this.m_n_master_id, s));
            this.start_item(st_burst);
            st_burst.m_n_slave_addr = n_addr;
            st_burst.m_n_rw         = 1'b0;
            st_burst.m_n_data_len   = 4;
            st_burst.m_an_data      = new[4];
            st_burst.m_an_data[0]   = n_burst_reg;
            st_burst.m_an_data[1]   = 8'hB0 + this.m_n_master_id[7:0];
            st_burst.m_an_data[2]   = 8'hD0 + s[7:0];
            st_burst.m_an_data[3]   = 8'hE0 + this.m_n_master_id[7:0] + s[7:0];
            st_burst.m_n_start      = 1'b1;
            st_burst.m_n_restart    = 1'b0;
            st_burst.m_n_stop       = 1'b1;
            this.finish_item(st_burst);

            st_ptr = smbus_transaction::type_id::create($sformatf("st_bptr_m%0d_s%0d", this.m_n_master_id, s));
            this.start_item(st_ptr);
            st_ptr.m_n_slave_addr = n_addr;
            st_ptr.m_n_rw         = 1'b0;
            st_ptr.m_n_data_len   = 1;
            st_ptr.m_an_data      = new[1];
            st_ptr.m_an_data[0]   = n_burst_reg;
            st_ptr.m_n_start      = 1'b1;
            st_ptr.m_n_restart    = 1'b0;
            st_ptr.m_n_stop       = 1'b0;
            this.finish_item(st_ptr);

            st_rd = smbus_transaction::type_id::create($sformatf("st_brd_m%0d_s%0d", this.m_n_master_id, s));
            this.start_item(st_rd);
            st_rd.m_n_slave_addr = n_addr;
            st_rd.m_n_rw         = 1'b1;
            st_rd.m_n_data_len   = 3;
            st_rd.m_n_start      = 1'b1;
            st_rd.m_n_restart    = 1'b1;
            st_rd.m_n_stop       = 1'b1;
            this.finish_item(st_rd);

            for (int b = 0; b < 3; b++) begin
                bit [7:0] n_exp_b;
                n_exp_b = st_burst.m_an_data[b + 1];
                if (st_rd.m_an_data.size() <= b || st_rd.m_an_data[b] !== n_exp_b) begin
                    `uvm_error("SEQ_TOPO", $sformatf("[M%0d->S%0d@0x%02h] Burst readback mismatch byte[%0d]: exp=0x%02h",
                               this.m_n_master_id, s, n_addr, b, n_exp_b))
                end
            end
        end

        // 3. Optional invalid address NACK check
        if (this.m_n_check_nack) begin
            st_nack = smbus_transaction::type_id::create($sformatf("st_nack_m%0d", this.m_n_master_id));
            this.start_item(st_nack);
            st_nack.m_n_slave_addr = 7'h55; // Unassigned address
            st_nack.m_n_rw         = 1'b0;
            st_nack.m_n_data_len   = 1;
            st_nack.m_an_data      = new[1];
            st_nack.m_an_data[0]   = 8'h00;
            st_nack.m_n_start      = 1'b1;
            st_nack.m_n_restart    = 1'b0;
            st_nack.m_n_stop       = 1'b1;
            this.finish_item(st_nack);

            if (st_nack.m_n_nack !== 1'b1) begin
                `uvm_error("SEQ_TOPO", $sformatf("[M%0d] Expected NACK for unassigned addr 0x55", this.m_n_master_id))
            end else begin
                `uvm_info("SEQ_TOPO", $sformatf("[M%0d] PASS: Unassigned addr 0x55 NACKed as expected", this.m_n_master_id), UVM_MEDIUM)
            end
        end
    endtask

endclass

`endif // SMBUS_IP_BASE_SEQUENCE_SV
