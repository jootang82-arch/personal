`ifndef SMBUS_MASTER_AGT_SV
`define SMBUS_MASTER_AGT_SV

class smbus_master_agt extends uvm_agent;

    typedef smbus_master_agt                t_smbus_master_agt;
    typedef smbus_master_sqr                t_smbus_master_sqr;
    typedef smbus_master_drv                t_smbus_master_drv;
    typedef virtual smbus_if                t_smbus_vif;

    t_smbus_master_sqr                      m_st_sqr;
    t_smbus_master_drv                      m_st_drv;
    t_smbus_vif                             m_st_vif;

    `uvm_component_utils(smbus_master_agt)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_master_agt", uvm_component st_parent = null);
        super.new(s_name, st_parent);
    endfunction

    // ========================================
    // build_phase
    // ========================================
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(t_smbus_vif)::get(this, "", "vif", this.m_st_vif)) begin
            `uvm_info("SMBUS_MAGT", "Virtual interface not found in agent config_db, will rely on child lookups", UVM_HIGH)
        end

        if (this.get_is_active() == UVM_ACTIVE) begin
            if (this.m_st_vif != null) begin
                uvm_config_db#(t_smbus_vif)::set(this, "m_st_drv", "vif", this.m_st_vif);
            end
            this.m_st_sqr = t_smbus_master_sqr::type_id::create("m_st_sqr", this);
            this.m_st_drv = t_smbus_master_drv::type_id::create("m_st_drv", this);
        end
    endfunction

    // ========================================
    // connect_phase
    // ========================================
    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        if (this.get_is_active() == UVM_ACTIVE) begin
            this.m_st_drv.seq_item_port.connect(this.m_st_sqr.seq_item_export);
            if (this.m_st_vif != null) begin
                this.m_st_drv.m_st_vif = this.m_st_vif;
            end
        end
    endfunction

endclass

`endif // SMBUS_MASTER_AGT_SV
