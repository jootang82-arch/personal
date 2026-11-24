`ifndef SMBUS_MASTER_SQR_SV
`define SMBUS_MASTER_SQR_SV

class smbus_master_sqr extends uvm_sequencer #(smbus_transaction);

    typedef smbus_master_sqr                t_smbus_master_sqr;

    `uvm_component_utils(smbus_master_sqr)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_master_sqr", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction

endclass

`endif // SMBUS_MASTER_SQR_SV
