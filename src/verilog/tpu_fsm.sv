import tpu_pkg::*;

module tpu_fsm (
    input logic i_clk,
    input logic i_rst_n,

    input logic i_start,
    output logic o_done,
    output logic o_busy,

    output logic o_weight_renable,
    output logic [ADDR_WIDTH-1:0] o_weight_raddr,
    output logic o_act_renable,
    output logic [ADDR_WIDTH-1:0] o_act_raddr,

    output logic [MAC_ARRAY_SIZE-1:0][MAC_ARRAY_SIZE-1:0] o_weight_load_mask,
    output logic o_row_valid,
    output logic [$clog2(MAC_ARRAY_SIZE)-1:0] o_row_fire,

    output logic o_mac_wenable,
    output logic [ADDR_WIDTH-1:0] o_mac_waddr,
    output logic [$clog2(MAC_ARRAY_SIZE)-1:0] o_wb_col
);

    localparam int N = MAC_ARRAY_SIZE;
    localparam int W_TOTAL = N * N;
    localparam int A_PER_ROW = N;
    localparam int A_ROWS = N;
    localparam int PIPE_LAT = N + N - 1;
    localparam int WB_TOTAL = N;

    localparam int W_W = $clog2(W_TOTAL);
    localparam int A_W = $clog2(A_PER_ROW);
    localparam int ROW_W = $clog2(A_ROWS);
    localparam int DRAIN_W = $clog2(PIPE_LAT);
    localparam int WB_W = $clog2(WB_TOTAL);

    typedef enum logic [2:0] {
        S_IDLE, S_LOAD_W, S_LOAD_ACT, S_COMPUTE, S_DRAIN, S_WRITEBACK, S_DONE
    } state_t;

    state_t state, next_state;

    logic [W_W-1:0] w_cnt;
    logic [A_W-1:0] act_buf_cnt;
    logic [ROW_W-1:0] row_cnt;
    logic [DRAIN_W-1:0] drain_cnt;
    logic [WB_W-1:0] wb_cnt;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            w_cnt <= '0;
            act_buf_cnt <= '0;
            row_cnt <= '0;
            drain_cnt <= '0;
            wb_cnt <= '0;
        end else begin
            case (state)
                S_LOAD_W:    
                    w_cnt <= w_cnt + 1'd1;
                S_LOAD_ACT: 
                    act_buf_cnt <= act_buf_cnt + 1'd1;
                S_COMPUTE: begin
                    act_buf_cnt <= '0;
                    row_cnt <= row_cnt + 1'd1;
                end
                S_DRAIN:     
                    drain_cnt <= drain_cnt + 1'd1;
                S_WRITEBACK: 
                    wb_cnt <= wb_cnt + 1'd1;
                default: begin
                    w_cnt <= '0;
                    act_buf_cnt <= '0;
                    row_cnt <= '0;
                    drain_cnt <= '0;
                    wb_cnt <= '0;
                end
            endcase
        end
    end

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            S_IDLE:      
                if (i_start)    
                    next_state = S_LOAD_W;
            S_LOAD_W:    
                if (w_cnt == W_TOTAL - 1)
                    next_state = S_LOAD_ACT;
            S_LOAD_ACT:  
                if (act_buf_cnt == A_PER_ROW - 1) 
                    next_state = S_COMPUTE;
            S_COMPUTE:   
                if (row_cnt == A_ROWS - 1)     
                    next_state = S_DRAIN;
                else                           
                    next_state = S_LOAD_ACT;
            S_DRAIN:     
                if (drain_cnt == PIPE_LAT - 1) 
                    next_state = S_WRITEBACK;
            S_WRITEBACK: 
                if (wb_cnt == WB_TOTAL - 1)    
                    next_state = S_DONE;
            S_DONE:      
                next_state = S_IDLE;
            default:     
                next_state = S_IDLE;
        endcase
    end

    logic [$clog2(N)-1:0] w_row, w_col;
    assign w_row = w_cnt / N;
    assign w_col = w_cnt % N;

    always_comb begin
        o_done = 1'b0;
        o_busy = 1'b0;
        o_weight_renable = 1'b0;
        o_weight_raddr = '0;
        o_act_renable = 1'b0;
        o_act_raddr = '0;
        o_weight_load_mask = '{default: 1'b0};
        o_row_valid = 1'b0;
        o_row_fire = '0;
        o_mac_wenable = 1'b0;
        o_mac_waddr = '0;
        o_wb_col = '0;

        case (state)
            S_IDLE: begin
            end

            S_LOAD_W: begin
                o_busy = 1'b1;
                o_weight_renable = 1'b1;
                o_weight_raddr = WEIGHT_BASE + w_cnt;
                o_weight_load_mask[w_row][w_col] = 1'b1;
            end

            S_LOAD_ACT: begin
                o_busy = 1'b1;
                o_act_renable = 1'b1;
                o_act_raddr = ACT_BASE + row_cnt * N + act_buf_cnt;
            end

            S_COMPUTE: begin
                o_busy = 1'b1;
                o_row_valid = 1'b1;
                o_row_fire = row_cnt;
            end

            S_DRAIN: begin
                o_busy = 1'b1;
            end

            S_WRITEBACK: begin
                o_busy = 1'b1;
                o_mac_wenable = 1'b1;
                o_mac_waddr = RESULT_BASE + wb_cnt;
                o_wb_col = wb_cnt;
            end

            S_DONE: begin
                o_done = 1'b1;
            end

            default: ;
        endcase
    end

endmodule