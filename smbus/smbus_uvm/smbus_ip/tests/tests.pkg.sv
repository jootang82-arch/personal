`ifndef TESTS_PKG
`define TESTS_PKG

package smbus_tests_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import smbus_ip_misc_pkg::*;
    import smbus_pkg::*;
    import smbus_ip_seq_pkg::*;
    import smbus_ip_env_pkg::*;

    `include "tc_base.sv"
    `include "tc_reset.sv"
    `include "tc_idle.sv"
    `include "tc_start_stop.sv"
    `include "tc_write.sv"
    `include "tc_read.sv"
    `include "tc_ack.sv"
    `include "tc_nack.sv"
    `include "tc_multi_byte.sv"
    `include "tc_restart.sv"
    `include "tc_random.sv"
    `include "tc_multi_topo.sv"

endpackage : smbus_tests_pkg

`endif // TESTS_PKG
