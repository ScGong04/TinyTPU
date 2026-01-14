// MAC cell is the module doing multiplications
// The std input width is defined as 16 bits and the std output width is defined as 32 bits
import tpu_pkg::*;
module mac_cell(
    input wire i_clk,
    input wire i_rst_n,
    input wire i_acc_clr,
    input wire [DATA_WIDTH-1:0] i_row, // row input
    input wire [DATA_WIDTH-1:0] i_col, // column input
    input wire [ACC_WIDTH-1:0] i_acc,
    output wire [DATA_WIDTH-1:0] o_row,
    output wire [DATA_WIDTH-1:0] o_col,
    output wire [ACC_WIDTH-1:0] o_acc
);
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin // reset
            o_row <= '0;
            o_col <= '0;
            o_acc  <= '0;
        end
        else begin
            o_row = i_row;           
            o_col = i_col;
            o_acc  = i_acc + i_row * i_col;
        end
    end
endmodule