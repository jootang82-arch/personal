`ifndef SMBUS_IP_SEQ_PKG
`define SMBUS_IP_SEQ_PKG

package smbus_ip_seq_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import smbus_ip_misc_pkg::*;
    import smbus_pkg::*;

    `include "smbus_ip_base_sequence.sv"

endpackage : smbus_ip_seq_pkg

`endif // SMBUS_IP_SEQ_PKG
