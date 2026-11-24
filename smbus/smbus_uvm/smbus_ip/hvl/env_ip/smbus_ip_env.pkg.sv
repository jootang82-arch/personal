`ifndef SMBUS_IP_ENV_PKG
`define SMBUS_IP_ENV_PKG

package smbus_ip_env_pkg;

    import uvm_pkg::*;
    `include "uvm_macros.svh"
    import smbus_ip_misc_pkg::*;
    import smbus_pkg::*;

    `include "smbus_ip_scoreboard.sv"
    `include "smbus_ip_env.sv"

endpackage : smbus_ip_env_pkg

`endif // SMBUS_IP_ENV_PKG
