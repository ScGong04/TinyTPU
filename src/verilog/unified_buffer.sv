import tpu_pkg::*;
module unified_buffer 
(
    input logic i_clk,
    input logic i_rst_n,

    input logic i_host_wenable,
    input logic [ADDR_WIDTH-1:0] i_host_waddr,
    input logic [ACC_WIDTH-1:0] i_host_wdata,
    output logic o_host_wready, // if the memory going to accept the write from the host
    input logic i_host_renable,
    input logic [ADDR_WIDTH-1:0] i_host_raddr,
    output logic [ACC_WIDTH-1:0] o_host_rdata,
    output logic o_host_valid
    // write back from the MAC array
    input logic i_mac_wenable,
    input logic [ADDR_WIDTH-1:0] i_mac_waddr,
    input logic [ACC_WIDTH:wadd-1:0] i_mac_wdata, 
    input logic i_row_renable,
    output logic o_row_valid // to indicate row reg has been loaded 
    input logic [ADDR_WIDTH-1:0] i_row_addr,
    output logic [ACC_WIDTH-1:0] o_row_data,
    input logic i_col_renable,
    input logic [ADDR_WIDTH-1:0] i_col_addr,
    output logic [ACC_WIDTH-1:0] o_col_data,
    output logic o_col_valid // to indicate col reg has been loaded 
)
    logic [ACC_WIDTH-1:0] mem_row [MEM_DEPTH-1 : 0];
    logic [ACC_WIDTH-1:0] mem_col [MEM_DEPTH-1 : 0];
    logic wenable;
    logic renable;
    logic [MEM_WIDTH-1:0] waddr;
    logic [ACC_WIDTH-1:0] wdata;
    
    always_comb begin
        wenable = 1'b0;
        waddr = '0;
        wdata = '0; 
        if(i_mac_wenable) begin
            wenable = 1'b1;
            waddr = i_mac_waddr;
            wdata = i_mac_wdata;
        end
        else if (i_host_wenable) begin
            wenable = 1'b1;
            waddr = i_host_waddr;
            wdata = i_host_wdata;
        end
    end

    assign o_host_wready = !i_mac_wenable;

    always_ff @(posedge i_clk) begin
        if (wenable) begin
            mem_col[waddr] <= wdata;
            mem_row[waddr] <= wdata;
        end
    end
    // loading row data setup
    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            o_row_valid <= 1'b0;
            o_row_rdata <= '0;
        end
        else begin
            o_row_valid <= i_row_renable;
            if (i_row_renable) begin
                o_row_data <= mem_row[i_row_addr];
            end
        end
    end
    // loading col data setup
    always_ff @(posedge i_clk) begin
        if (!i_rst_n) begin
            o_col_valid <= 1'b0;
            o_col_rdata <= '0;
        end
        else begin
            o_col_valid <= i_col_renable;
            if (i_col_renable) begin
                o_col_data <= mem_col[i_col_addr];
            end
        end
    end
    // host reading data
    logic host_re_grant;
    assign host_re_grant = i_host_renable && !i_col_renable;
    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            o_host_valid <= 1'b0;
            o_host_rdata <= '0;
        end
        else begin
            o_host_valid <= host_re_grant;
            if (host_re_grant) begin
                o_host_rdata <= mem_col[i_host_raddr];
            end
        end      
    end

    assign o_host_rdata = rdata;
endmodule