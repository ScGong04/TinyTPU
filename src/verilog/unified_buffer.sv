import tpu_pkg::*;
module unified_buffer 
(
    input logic i_clk,
    input logic i_rst_n,

    input logic i_host_wenable,
    input logic [ADDR_WIDTH-1:0] i_host_waddr,
    input logic [DATA_WIDTH-1:0] i_host_wdata,
    output logic o_host_wready, // if the memory going to accept the write from the host

    input logic i_host_renable,
    input logic [ADDR_WIDTH-1:0] i_host_raddr,
    output logic [DATA_WIDTH-1:0] o_host_rdata,
    output logic o_host_valid,

    // write back from the MAC array
    input logic i_mac_wenable,
    input logic [ADDR_WIDTH-1:0] i_mac_waddr,
    input logic [ACC_WIDTH-1:0] i_mac_wdata, 

    input logic i_row_renable,
    input logic [ADDR_WIDTH-1:0] i_row_addr,
    output logic [ACC_WIDTH-1:0] o_row_data,
    output logic o_row_valid // to indicate row reg has been loaded 
)
    logic [ACC_WIDTH-1:0] mem [MEM_DEPTH-1 : 0];

    always_ff @(posedge i_clk) begin
        if (i_host_wenable) begin
            mem[i_host_waddr] <= {{(ACC_WIDTH-DATA_WIDTH){i_host_wdata[DATA_WIDTH-1]}}, i_host_wdata};
        end
        else if (i_mac_wenable) begin
            mem[i_mac_waddr] <= i_mac_wdata;
        end
    end

    logic host_read_grant;
    assign host_read_grant = i_host_renable && ! i_row_renable;

    // loading row data setup
    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            o_row_valid <= 1'b0;
            o_row_rdata <= '0;
        end
        else begin
            o_row_valid <= i_row_renable;
            if (i_row_renable) begin
                o_row_data <= mem_row[i_row_addr][DATA_WIDTH-1:0];
            end
        end
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_host_valid <= 1'b0;
            o_host_rdata <= '0;
        end
        else begin
            o_host_valid <= host_read_grant;
            if (host_re_grant) begin
                o_host_rdata <= mem_col[i_host_raddr][DATA_WIDTH-1:0];
            end
        end      
    end
endmodule