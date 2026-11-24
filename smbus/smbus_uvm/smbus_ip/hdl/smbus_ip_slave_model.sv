`ifndef SMBUS_IP_SLAVE_MODEL_SV
`define SMBUS_IP_SLAVE_MODEL_SV

// Behavioral / synthesizable SMBus Slave Model for IP verification
module smbus_ip_slave_model #(
    parameter bit [6:0] SLAVE_ADDR = 7'h2A
)(
    input  logic clk,
    input  logic rst_n,
    inout  wire  scl,
    inout  wire  sda,
    output logic slave_scl_oe,
    output logic slave_sda_oe
);

    typedef enum bit [3:0] {
        ST_IDLE,
        ST_ADDR,
        ST_ADDR_ACK,
        ST_WRITE_DATA,
        ST_WRITE_ACK,
        ST_READ_DATA,
        ST_READ_ACK
    } e_slave_state;

    e_slave_state state, state_next;

    // Synchronizers & edge detectors for SCL and SDA
    logic [2:0] scl_pipe;
    logic [2:0] sda_pipe;
    wire scl_sync = scl_pipe[1];
    wire sda_sync = sda_pipe[1];
    wire scl_rise = (scl_pipe[2:1] == 2'b01);
    wire scl_fall = (scl_pipe[2:1] == 2'b10);
    wire sda_rise = (sda_pipe[2:1] == 2'b01);
    wire sda_fall = (sda_pipe[2:1] == 2'b10);

    // Asynchronous START and STOP condition detection
    wire start_cond = (scl_sync && sda_fall);
    wire stop_cond  = (scl_sync && sda_rise);

    // Internal registers
    logic [7:0] mem [0:255];
    logic [7:0] reg_addr;
    logic [2:0] bit_cnt;
    logic [7:0] shift_reg;
    logic       rw_bit;
    logic       addr_matched;
    logic       first_byte_received;
    logic       ack_driven;
    logic       master_ack_sampled;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_pipe <= 3'b111;
            sda_pipe <= 3'b111;
        end else begin
            scl_pipe <= {scl_pipe[1:0], scl};
            sda_pipe <= {sda_pipe[1:0], sda};
        end
    end

    // Slave FSM and operations
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state               <= ST_IDLE;
            slave_scl_oe        <= 1'b0;
            slave_sda_oe        <= 1'b0;
            bit_cnt             <= 3'd7;
            shift_reg           <= 8'h00;
            rw_bit              <= 1'b0;
            addr_matched        <= 1'b0;
            reg_addr            <= 8'h00;
            first_byte_received <= 1'b0;
            ack_driven          <= 1'b0;
            master_ack_sampled  <= 1'b1;
            for (int i = 0; i < 256; i++) begin
                mem[i] <= 8'hA0 + i[7:0]; // Initial predictable memory values
            end
        end else if (stop_cond) begin
            state               <= ST_IDLE;
            slave_scl_oe        <= 1'b0;
            slave_sda_oe        <= 1'b0;
            addr_matched        <= 1'b0;
            first_byte_received <= 1'b0;
            ack_driven          <= 1'b0;
            master_ack_sampled  <= 1'b1;
        end else if (start_cond) begin
            state               <= ST_ADDR;
            bit_cnt             <= 3'd7;
            slave_scl_oe        <= 1'b0;
            slave_sda_oe        <= 1'b0;
            addr_matched        <= 1'b0;
            first_byte_received <= 1'b0;
            ack_driven          <= 1'b0;
            master_ack_sampled  <= 1'b1;
        end else begin
            case (state)
                ST_IDLE: begin
                    slave_scl_oe <= 1'b0;
                    slave_sda_oe <= 1'b0;
                    ack_driven   <= 1'b0;
                end

                ST_ADDR: begin
                    if (scl_rise) begin
                        shift_reg[bit_cnt] <= sda_sync;
                        if (bit_cnt == 0) begin
                            state      <= ST_ADDR_ACK;
                            ack_driven <= 1'b0;
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                        end
                    end
                end

                ST_ADDR_ACK: begin
                    if (scl_fall) begin
                        if (!ack_driven) begin
                            if (shift_reg[7:1] == SLAVE_ADDR) begin
                                addr_matched <= 1'b1;
                                rw_bit       <= shift_reg[0];
                                slave_sda_oe <= 1'b1; // Drive ACK (Low)
                                ack_driven   <= 1'b1;
                            end else begin
                                addr_matched <= 1'b0;
                                slave_sda_oe <= 1'b0; // NACK
                                state        <= ST_IDLE;
                            end
                        end else begin
                            // Release ACK and move to next state
                            ack_driven   <= 1'b0;
                            bit_cnt      <= 3'd7;
                            if (rw_bit == 1'b0) begin
                                slave_sda_oe <= 1'b0;
                                state        <= ST_WRITE_DATA;
                            end else begin
                                state        <= ST_READ_DATA;
                                shift_reg    <= mem[reg_addr];
                                slave_sda_oe <= (mem[reg_addr][7] == 1'b0);
                            end
                        end
                    end
                end

                ST_WRITE_DATA: begin
                    if (scl_rise) begin
                        shift_reg[bit_cnt] <= sda_sync;
                        if (bit_cnt == 0) begin
                            state      <= ST_WRITE_ACK;
                            ack_driven <= 1'b0;
                        end else begin
                            bit_cnt <= bit_cnt - 1'b1;
                        end
                    end
                end

                ST_WRITE_ACK: begin
                    if (scl_fall) begin
                        if (!ack_driven) begin
                            slave_sda_oe <= 1'b1; // ACK byte
                            ack_driven   <= 1'b1;
                            if (!first_byte_received) begin
                                reg_addr            <= shift_reg;
                                first_byte_received <= 1'b1;
                            end else begin
                                mem[reg_addr] <= shift_reg;
                                reg_addr      <= reg_addr + 1'b1;
                            end
                        end else begin
                            slave_sda_oe <= 1'b0;
                            ack_driven   <= 1'b0;
                            bit_cnt      <= 3'd7;
                            state        <= ST_WRITE_DATA;
                        end
                    end
                end

                ST_READ_DATA: begin
                    if (scl_fall) begin
                        if (bit_cnt == 0) begin
                            state        <= ST_READ_ACK;
                            slave_sda_oe <= 1'b0; // Release for Master ACK
                        end else begin
                            bit_cnt      <= bit_cnt - 1'b1;
                            slave_sda_oe <= (shift_reg[bit_cnt - 1'b1] == 1'b0);
                        end
                    end
                end

                ST_READ_ACK: begin
                    if (scl_rise) begin
                        master_ack_sampled <= sda_sync;
                        ack_driven         <= 1'b1;
                    end else if (scl_fall && ack_driven) begin
                        ack_driven <= 1'b0;
                        reg_addr   <= reg_addr + 1'b1;
                        if (master_ack_sampled == 1'b1) begin
                            // Master NACK -> transaction ending
                            slave_sda_oe <= 1'b0;
                            state        <= ST_IDLE;
                        end else begin
                            // Master ACK -> drive MSB of next byte on 9th clock fall
                            bit_cnt      <= 3'd7;
                            shift_reg    <= mem[reg_addr + 1'b1];
                            state        <= ST_READ_DATA;
                            slave_sda_oe <= (mem[reg_addr + 1'b1][7] == 1'b0);
                        end
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule : smbus_ip_slave_model

`endif // SMBUS_IP_SLAVE_MODEL_SV
