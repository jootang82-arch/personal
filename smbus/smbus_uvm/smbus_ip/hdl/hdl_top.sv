`ifndef HDL_TOP_SV
`define HDL_TOP_SV

`timescale 1ns/1ps

`ifndef NUM_SLAVE
    `define NUM_SLAVE 1
`endif

`ifndef MAX_MASTER_IF
    `define MAX_MASTER_IF 2
`endif

import uvm_pkg::*;
`include "uvm_macros.svh"

module hdl_top;

    logic clk;
    logic rst_n;

    // Shared physical open-drain SMBus bus signals
    tri1 scl;
    tri1 sda;
    pullup (scl);
    pullup (sda);

    // 50 MHz clock generation (20 ns period)
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // Reset generation
    initial begin
        rst_n = 1'b0;
        #100;
        rst_n = 1'b1;
    end

    // Monitor / common observation VIP interface (single-endpoint, passive)
    smbus_if u_mon_if (
        .clk   (clk),
        .rst_n (rst_n),
        .scl   (scl),
        .sda   (sda)
    );

    // Single-endpoint VIP Master interfaces connected to shared physical bus
    generate
        for (genvar m = 0; m < `MAX_MASTER_IF; m++) begin : gen_master_if
            smbus_if u_smbus_if (
                .clk   (clk),
                .rst_n (rst_n),
                .scl   (scl),
                .sda   (sda)
            );

            initial begin
                uvm_config_db#(virtual smbus_if)::set(
                    null, "*", $sformatf("master_vif_%0d", m), u_smbus_if
                );
            end
        end
    endgenerate

    // Hardware DUT SMBus Slave Model instances controlled by `NUM_SLAVE define
    logic [`NUM_SLAVE-1:0] dut_scl_oe;
    logic [`NUM_SLAVE-1:0] dut_sda_oe;

    assign scl = (|dut_scl_oe) ? 1'b0 : 1'bz;
    assign sda = (|dut_sda_oe) ? 1'b0 : 1'bz;

    generate
        for (genvar s = 0; s < `NUM_SLAVE; s++) begin : gen_slave_dut
            smbus_ip_slave_model #(
                .SLAVE_ADDR(7'h2A + 7'(s))
            ) u_dut (
                .clk          (clk),
                .rst_n        (rst_n),
                .scl          (scl),
                .sda          (sda),
                .slave_scl_oe (dut_scl_oe[s]),
                .slave_sda_oe (dut_sda_oe[s])
            );
        end
    endgenerate

    // Export common virtual interface and compiled NUM_SLAVE count to UVM config_db
    initial begin
        uvm_config_db#(virtual smbus_if)::set(null, "*", "vif", u_mon_if);
        uvm_config_db#(virtual smbus_if)::set(null, "*", "mon_vif", u_mon_if);
        uvm_config_db#(int)::set(null, "*", "num_slaves", `NUM_SLAVE);
    end

endmodule : hdl_top

`endif // HDL_TOP_SV
