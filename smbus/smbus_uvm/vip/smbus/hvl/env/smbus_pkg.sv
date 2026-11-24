`ifndef SMBUS_PKG_SV
`define SMBUS_PKG_SV

package smbus_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    `include "smbus_seq_item.sv"
    `include "smbus_master_sqr.sv"
    `include "smbus_master_drv.sv"
    `include "smbus_slave_sqr.sv"
    `include "smbus_slave_drv.sv"
    `include "smbus_mon.sv"
    `include "smbus_master_agt.sv"
    `include "smbus_slave_agt.sv"
    `include "smbus_base_sequence.sv"
    `include "smbus_master_sequence.sv"
    `include "smbus_slave_sequence.sv"

endpackage : smbus_pkg

`endif // SMBUS_PKG_SV
