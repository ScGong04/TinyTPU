// MAC cell is the module doing multiplications
// The std input width is defined as 16 bits and the std output width is defined as 32 bits
module mac_cell #(
    DATA_WIDTH = 16,
    ACC_WIDTH = 32
)(
    input wire i_clk,
    input wire i_rst_n,
    input wire [DATA_WIDTH-1:0] i_hori, // horizontal input
    input wire [DATA_WIDTH-1:0] i_vert, // vertical input
    input wire [ACC_WIDTH-1:0] i_acc,
    output wire [DATA_WIDTH-1:0] o_hori,
    output wire [DATA_WIDTH-1:0] o_vert,
    output wire [ACC_WIDTH-1:0] o_acc
);
    always @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin // reset
            o_hori <= '0;
            o_vert <= '0;
            o_acc  <= '0;
        end
        else begin
            o_hori = i_hori;           
            o_vert = i_vert;
            o_acc  = i_acc + i_hori * i_vert;
        end
    end
endmodule