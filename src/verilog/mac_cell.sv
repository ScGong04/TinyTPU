// MAC cell is the module that does multiplications
// The std input width is defined as 16 bits and the std output width is defined as 32 bits
import tpu_pkg::*;
module mac_cell(
    input logic i_clk,
    input logic i_rst_n,
    input logic i_weight_load,
    input logic [DATA_WIDTH-1:0] i_row, // row input
    input logic [DATA_WIDTH-1:0] i_col, // column input
    input logic [ACC_WIDTH-1:0] i_acc,
    output logic [DATA_WIDTH-1:0] o_row,
    output logic [DATA_WIDTH-1:0] o_col,
    output logic [ACC_WIDTH-1:0] o_acc
);
    logic [DATA_WIDTH-1:0] weight_reg;
    logic [DATA_WIDTH-1:0] row_reg;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            weight_reg <= '0;
            row_reg <= '0;
            o_acc <= '0;
        end else begin
            if (i_weight_load) begin
                weight_reg <= i_col;
                o_acc <= '0;
            end 
            else begin
                row_reg <= i_row;
                o_acc <= i_acc + i_row * weight_reg;
            end
        end
    end

    assign o_row = row_reg;
    assign o_col = i_weight_load ? i_col : weight_reg;

endmodule