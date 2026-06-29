import tpu_pkg::*;

module systolic_data_setup (
    input logic i_clk,
    input logic i_rst_n,
    input logic i_valid,  
    input logic [DATA_WIDTH-1:0] i_data [MAC_ARRAY_SIZE-1:0],
    output logic [DATA_WIDTH-1:0] o_data [MAC_ARRAY_SIZE-1:0],
    output logic [MAC_ARRAY_SIZE-1:0] o_valid 
);
    logic [DATA_WIDTH-1:0] skew_pipe [MAC_ARRAY_SIZE-1:0][MAC_ARRAY_SIZE-1:0];
    logic [MAC_ARRAY_SIZE-1:0] valid_pipe [MAC_ARRAY_SIZE-1:0];

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin // initialize empty array
            for (int i = 0; i < MAC_ARRAY_SIZE; i++) begin
                for (int j = 0; j < MAC_ARRAY_SIZE; j++) begin
                    skew_pipe[i][j] <= '0;
                    valid_pipe[i][j] <= 1'b0;
                end
            end
        end 
        else begin
            for (int i = 0; i < MAC_ARRAY_SIZE; i++) begin
                // generate LTM
                skew_pipe[i][0] <= i_data[i];
                valid_pipe[i][0] <= i_valid;

                for (int j = 1; j < MAC_ARRAY_SIZE; j++) begin // delay generation
                    skew_pipe[i][j] <= skew_pipe[i][j-1];
                    valid_pipe[i][j] <= valid_pipe[i][j-1];
                end
            end
        end
    end

    for (genvar i = 0; i < MAC_ARRAY_SIZE; i++) begin
        assign o_data[i] = skew_pipe[i][i];
        assign o_valid[i] = valid_pipe[i][i];
    end
endmodule
