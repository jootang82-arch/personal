`ifndef HVL_TOP_SV
`define HVL_TOP_SV

`timescale 1ns/1ps

import uvm_pkg::*;
`include "uvm_macros.svh"
import smbus_tests_pkg::*;

module hvl_top;

    initial begin
        `uvm_info("HVL_TOP", "Starting SMBus UVM Testbench execution...", UVM_LOW)
        run_test();
    end

endmodule : hvl_top

`endif // HVL_TOP_SV
