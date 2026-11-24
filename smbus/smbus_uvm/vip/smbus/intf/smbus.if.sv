`ifndef SMBUS_IF_SV
`define SMBUS_IF_SV

interface smbus_if (
    input logic clk,
    input logic rst_n,
    inout wire  scl,
    inout wire  sda
);

    // Single-endpoint open-drain driver control signals (1 = pull LOW, 0 = release Z)
    logic master_scl_oe;
    logic master_sda_oe;
    logic slave_scl_oe;
    logic slave_sda_oe;

    // Bus busy indicator (1 between START and STOP on the shared physical bus)
    logic bus_busy;

    // Drive open-drain onto shared physical bus
    assign scl = (master_scl_oe || slave_scl_oe) ? 1'b0 : 1'bz;
    assign sda = (master_sda_oe || slave_sda_oe) ? 1'b0 : 1'bz;

    // Initialize driver controls
    initial begin
        master_scl_oe = 1'b0;
        master_sda_oe = 1'b0;
        slave_scl_oe  = 1'b0;
        slave_sda_oe  = 1'b0;
        bus_busy      = 1'b0;
    end

    // Track bus busy status via START / STOP conditions on shared bus
    always @(negedge rst_n) begin
        bus_busy <= 1'b0;
    end

    always @(negedge sda) begin
        if (rst_n === 1'b1 && scl === 1'b1) begin
            bus_busy <= 1'b1;
        end
    end

    always @(posedge sda) begin
        if (rst_n === 1'b1 && scl === 1'b1) begin
            bus_busy <= 1'b0;
        end
    end

    // ========================================
    // master_release_bus
    // ========================================
    task automatic master_release_bus();
        master_scl_oe = 1'b0;
        master_sda_oe = 1'b0;
    endtask

    // ========================================
    // master_drive_scl_low
    // ========================================
    task automatic master_drive_scl_low();
        master_scl_oe = 1'b1;
    endtask

    // ========================================
    // master_release_scl
    // ========================================
    task automatic master_release_scl();
        master_scl_oe = 1'b0;
    endtask

    // ========================================
    // master_drive_sda_low
    // ========================================
    task automatic master_drive_sda_low();
        master_sda_oe = 1'b1;
    endtask

    // ========================================
    // master_release_sda
    // ========================================
    task automatic master_release_sda();
        master_sda_oe = 1'b0;
    endtask

    // ========================================
    // slave_release_bus
    // ========================================
    task automatic slave_release_bus();
        slave_scl_oe = 1'b0;
        slave_sda_oe = 1'b0;
    endtask

    // ========================================
    // slave_drive_scl_low
    // ========================================
    task automatic slave_drive_scl_low();
        slave_scl_oe = 1'b1;
    endtask

    // ========================================
    // slave_release_scl
    // ========================================
    task automatic slave_release_scl();
        slave_scl_oe = 1'b0;
    endtask

    // ========================================
    // slave_drive_sda_low
    // ========================================
    task automatic slave_drive_sda_low();
        slave_sda_oe = 1'b1;
    endtask

    // ========================================
    // slave_release_sda
    // ========================================
    task automatic slave_release_sda();
        slave_sda_oe = 1'b0;
    endtask

endinterface : smbus_if

`endif // SMBUS_IF_SV
