`ifndef SMBUS_IP_PORT_SV
`define SMBUS_IP_PORT_SV

class smbus_ip_port;

    typedef smbus_ip_port                   t_smbus_ip_port;

    parameter int SMBUS_ADDR_WIDTH         = 7;
    parameter int SMBUS_DATA_WIDTH         = 8;
    parameter int SMBUS_DEFAULT_SLAVE_ADDR = 7'h2A;
    parameter int SMBUS_CLK_PERIOD_NS      = 10000; // 100 kHz (10 us)
    parameter int SMBUS_TIMEOUT_CYCLES     = 3500;  // 35 ms timeout limit
    parameter int SMBUS_MAX_BLOCK_LENGTH   = 32;

    // ========================================
    // new
    // ========================================
    function new();
    endfunction

endclass

`endif // SMBUS_IP_PORT_SV
