import tpu_pkg::*;

module unified_buffer (
    input logic i_clk,
    input logic i_rst_n,

    input logic i_host_wenable,
    input logic [ADDR_WIDTH-1:0] i_host_waddr,
    input logic [DATA_WIDTH-1:0] i_host_wdata,
    output logic o_host_wready,

    input logic i_host_renable,
    input logic [ADDR_WIDTH-1:0] i_host_raddr,
    output logic [DATA_WIDTH-1:0] o_host_rdata,
    output logic o_host_valid,

    input logic i_mac_wenable,
    input logic [ADDR_WIDTH-1:0] i_mac_waddr,
    input logic [ACC_WIDTH-1:0] i_mac_wdata,

    input logic i_weight_renable,
    input logic [ADDR_WIDTH-1:0] i_weight_raddr,
    output logic [DATA_WIDTH-1:0] o_weight_rdata,
    output logic o_weight_valid,

    input logic i_act_renable,
    input logic [ADDR_WIDTH-1:0] i_act_raddr,
    output logic [DATA_WIDTH-1:0] o_act_rdata,
    output logic o_act_valid
);
    
    logic [ACC_WIDTH-1:0] mem [MEM_DEPTH-1:0];

    always_ff @(posedge i_clk) begin
        if (i_host_wenable) begin
            mem[i_host_waddr] <= {{(ACC_WIDTH-DATA_WIDTH){i_host_wdata[DATA_WIDTH-1]}}, i_host_wdata};
        end 
        else if (i_mac_wenable) begin
            mem[i_mac_waddr] <= i_mac_wdata;
        end
    end
    assign o_host_wready = 1'b1;  

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_host_valid <= 1'b0;
            o_host_rdata <= '0;
            o_weight_valid <= 1'b0;
            o_weight_rdata <= '0;
            o_act_valid <= 1'b0;
            o_act_rdata <= '0;
        end 
        else begin
            // Host read
            o_host_valid <= i_host_renable;
            o_host_rdata <= i_host_renable ? mem[i_host_raddr][DATA_WIDTH-1:0] : o_host_rdata;

            // Weight read
            o_weight_valid <= i_weight_renable;
            o_weight_rdata <= i_weight_renable ? mem[i_weight_raddr][DATA_WIDTH-1:0] : o_weight_rdata;

            // Activation read
            o_act_valid <= i_act_renable;
            o_act_rdata <= i_act_renable ? mem[i_act_raddr][DATA_WIDTH-1:0] : o_act_rdata;
        end
    end

endmodule