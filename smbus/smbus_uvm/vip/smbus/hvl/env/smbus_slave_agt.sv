`ifndef SMBUS_SLAVE_AGT_SV
`define SMBUS_SLAVE_AGT_SV

class smbus_slave_agt extends uvm_agent;

    typedef smbus_slave_agt                 t_smbus_slave_agt;
    typedef smbus_slave_sqr                 t_smbus_slave_sqr;
    typedef smbus_slave_drv                 t_smbus_slave_drv;
    typedef virtual smbus_if                t_smbus_vif;

    t_smbus_slave_sqr                       m_st_sqr;
    t_smbus_slave_drv                       m_st_drv;
    t_smbus_vif                             m_st_vif;
    bit [6:0]                               m_n_slave_addr;

    `uvm_component_utils(smbus_slave_agt)

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_slave_agt", uvm_component st_parent = null);
        super.new(s_name, st_parent);
        this.m_n_slave_addr = 7'h2A;
    endfunction

    // ========================================
    // build_phase
    // ========================================
    function void build_phase(uvm_phase phase);
        int n_addr_cfg;
        super.build_phase(phase);

        if (!uvm_config_db#(t_smbus_vif)::get(this, "", "vif", this.m_st_vif)) begin
            `uvm_info("SMBUS_SAGT", "Virtual interface not found in agent config_db, will rely on child lookups", UVM_HIGH)
        end
        if (uvm_config_db#(int)::get(this, "", "slave_addr", n_addr_cfg)) begin
            this.m_n_slave_addr = n_addr_cfg[6:0];
        end

        if (this.get_is_active() == UVM_ACTIVE) begin
            if (this.m_st_vif != null) begin
                uvm_config_db#(t_smbus_vif)::set(this, "m_st_drv", "vif", this.m_st_vif);
            end
            uvm_config_db#(int)::set(this, "m_st_drv", "slave_addr", int'(this.m_n_slave_addr));
            this.m_st_sqr = t_smbus_slave_sqr::type_id::create("m_st_sqr", this);
            this.m_st_drv = t_smbus_slave_drv::type_id::create("m_st_drv", this);
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
            this.m_st_drv.m_n_slave_addr = this.m_n_slave_addr;
        end
    endfunction

endclass

`endif // SMBUS_SLAVE_AGT_SV
