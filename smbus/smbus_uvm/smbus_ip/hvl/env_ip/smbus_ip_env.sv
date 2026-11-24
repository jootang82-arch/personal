`ifndef SMBUS_IP_ENV_SV
`define SMBUS_IP_ENV_SV

class smbus_ip_env #(
    int NUM_MASTER = 1
) extends uvm_env;

    typedef smbus_ip_env #(NUM_MASTER)      t_smbus_ip_env;
    typedef smbus_master_agt                t_smbus_master_agt;
    typedef smbus_slave_agt                 t_smbus_slave_agt;
    typedef smbus_mon                       t_smbus_mon;
    typedef smbus_ip_scoreboard             t_smbus_ip_scoreboard;
    typedef virtual smbus_if                t_smbus_vif;

    // Master Agent array created according to NUM_MASTER parameter
    t_smbus_master_agt                      m_ast_master_agt [NUM_MASTER];
    t_smbus_vif                             m_ast_master_vif [NUM_MASTER];

    // Legacy single-agent handles (Master[0] alias + optional single VIP slave)
    t_smbus_master_agt                      m_st_smbus_master_agt;
    t_smbus_slave_agt                       m_st_smbus_slave_agt;

    t_smbus_mon                             m_st_smbus_mon;
    t_smbus_ip_scoreboard                   m_st_scoreboard;
    t_smbus_vif                             m_st_vif;

    int                                     m_n_num_masters;
    int                                     m_n_num_slaves;

    `uvm_component_param_utils(smbus_ip_env #(NUM_MASTER))

    // ========================================
    // new
    // ========================================
    function new(string s_name = "smbus_ip_env", uvm_component st_parent = null);
        super.new(s_name, st_parent);
        this.m_n_num_masters = NUM_MASTER;
        this.m_n_num_slaves  = 1;
    endfunction

    // ========================================
    // build_phase
    // ========================================
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (NUM_MASTER < 1) begin
            `uvm_fatal("SMBUS_ENV", $sformatf("Invalid NUM_MASTER=%0d (must be >= 1)", NUM_MASTER))
        end

        if (!uvm_config_db#(t_smbus_vif)::get(this, "", "vif", this.m_st_vif)) begin
            `uvm_info("SMBUS_ENV", "Common virtual interface not explicitly passed to env, propagating from top", UVM_HIGH)
        end

        // Read compiled HDL DUT slave count (`NUM_SLAVE in hdl_top)
        void'(uvm_config_db#(int)::get(this, "", "num_slaves", this.m_n_num_slaves));
        if (this.m_n_num_slaves < 1 || this.m_n_num_slaves > 4) begin
            `uvm_fatal("SMBUS_ENV", $sformatf("Invalid num_slaves=%0d (must be 1..4)", this.m_n_num_slaves))
        end

        `uvm_info("SMBUS_ENV", $sformatf("Building smbus_ip_env #(NUM_MASTER=%0d) for %0d HDL DUT Slave(s)",
                  NUM_MASTER, this.m_n_num_slaves), UVM_LOW)

        // Instantiate NUM_MASTER independent single-master VIP agents
        for (int m = 0; m < NUM_MASTER; m++) begin
            string s_agt_name;
            string s_vif_key;
            s_agt_name = (m == 0) ? "m_st_smbus_master_agt" : $sformatf("m_st_smbus_master_agt_%0d", m);
            s_vif_key  = $sformatf("master_vif_%0d", m);

            if (!uvm_config_db#(t_smbus_vif)::get(this, "", s_vif_key, this.m_ast_master_vif[m])) begin
                this.m_ast_master_vif[m] = this.m_st_vif;
            end
            if (this.m_ast_master_vif[m] == null) begin
                `uvm_fatal("SMBUS_ENV", $sformatf("Virtual interface '%s' not found for Master[%0d]", s_vif_key, m))
            end

            uvm_config_db#(t_smbus_vif)::set(this, {s_agt_name, "*"}, "vif", this.m_ast_master_vif[m]);
            uvm_config_db#(int)::set(this, {s_agt_name, ".m_st_drv"}, "bus_free_extra_ns", m * 50);
            this.m_ast_master_agt[m] = t_smbus_master_agt::type_id::create(s_agt_name, this);
        end

        // Alias index 0 master agent for legacy sequences/tests
        this.m_st_smbus_master_agt = this.m_ast_master_agt[0];

        // Single optional VIP Slave Agent (disabled by default when HDL DUT slave_model is active)
        if (this.m_st_vif != null) begin
            uvm_config_db#(t_smbus_vif)::set(this, "m_st_smbus_slave_agt*", "vif", this.m_st_vif);
            uvm_config_db#(t_smbus_vif)::set(this, "m_st_smbus_mon*",       "vif", this.m_st_vif);
        end
        this.m_st_smbus_slave_agt = t_smbus_slave_agt::type_id::create("m_st_smbus_slave_agt", this);
        this.m_st_smbus_mon       = t_smbus_mon::type_id::create("m_st_smbus_mon", this);
        this.m_st_scoreboard      = t_smbus_ip_scoreboard::type_id::create("m_st_scoreboard", this);
    endfunction

    // ========================================
    // connect_phase
    // ========================================
    function void connect_phase(uvm_phase phase);
        bit [6:0] an_slave_addrs[];
        super.connect_phase(phase);

        // Connect Common Monitor analysis port to IP Scoreboard
        this.m_st_smbus_mon.m_st_ap.connect(this.m_st_scoreboard.m_st_mon_export);

        // Register all active HDL DUT slave addresses (0x2A + s) with the scoreboard
        an_slave_addrs = new[this.m_n_num_slaves];
        for (int s = 0; s < this.m_n_num_slaves; s++) begin
            an_slave_addrs[s] = smbus_ip_port::SMBUS_DEFAULT_SLAVE_ADDR + s[6:0];
        end
        this.m_st_scoreboard.configure_slaves(this.m_n_num_slaves, an_slave_addrs);
    endfunction

endclass

`endif // SMBUS_IP_ENV_SV
