`ifndef SMBUS_SLAVE_SQR_SV
`define SMBUS_SLAVE_SQR_SV

class smbus_slave_sqr extends uvm_sequencer #(smbus_transaction);

    typedef smbus_slave_sqr                 t_smbus_slave_sqr;

    `uvm_component_utils(smbus_slave_sqr)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_slave_sqr", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction

endclass

`endif // SMBUS_SLAVE_SQR_SV
