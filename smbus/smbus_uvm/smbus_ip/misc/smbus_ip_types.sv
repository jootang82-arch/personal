`ifndef SMBUS_IP_TYPES_SV
`define SMBUS_IP_TYPES_SV

class smbus_ip_types;

    typedef smbus_ip_types                  t_smbus_ip_types;

    typedef enum bit {
        SMBUS_WRITE = 1'b0,
        SMBUS_READ  = 1'b1
    } e_smbus_direction;

    typedef enum bit {
        SMBUS_ACK  = 1'b0,
        SMBUS_NACK = 1'b1
    } e_smbus_response;

    typedef enum bit [2:0] {
        SMBUS_TRANS_QUICK,
        SMBUS_TRANS_BYTE,
        SMBUS_TRANS_BYTE_DATA,
        SMBUS_TRANS_WORD_DATA,
        SMBUS_TRANS_BLOCK,
        SMBUS_TRANS_RESTART
    } e_smbus_trans_type;

    typedef enum bit [1:0] {
        SMBUS_STATUS_OK       = 2'b00,
        SMBUS_STATUS_NACK     = 2'b01,
        SMBUS_STATUS_TIMEOUT  = 2'b10,
        SMBUS_STATUS_ERROR    = 2'b11
    } e_smbus_status;

    // ========================================
    // new
    // ========================================
    function new();
    endfunction

endclass

`endif // SMBUS_IP_TYPES_SV
