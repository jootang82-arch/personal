`ifndef SMBUS_BASE_SEQUENCE_SV
`define SMBUS_BASE_SEQUENCE_SV

class smbus_base_sequence extends uvm_sequence #(smbus_transaction);

    typedef smbus_base_sequence             t_smbus_base_sequence;

    `uvm_object_utils(smbus_base_sequence)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_base_sequence");
        super.new(s_name);
    endfunction

    // ========================================
    // pre_body
    // ========================================
    task pre_body();
        if (this.starting_phase != null) begin
            this.starting_phase.raise_objection(this, {"Running sequence ", this.get_name()});
        end
    endtask

    // ========================================
    // post_body
    // ========================================
    task post_body();
        if (this.starting_phase != null) begin
            this.starting_phase.drop_objection(this, {"Completed sequence ", this.get_name()});
        end
    endtask

endclass

`endif // SMBUS_BASE_SEQUENCE_SV
