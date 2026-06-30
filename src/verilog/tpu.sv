import tpu_pkg::*;

module tpu (
    input logic i_clk,
    input logic i_rst_n,

    input logic i_start,
    output logic o_done,
    output logic o_busy,

    input logic i_host_wenable,
    input logic [ADDR_WIDTH-1:0] i_host_waddr,
    input logic [DATA_WIDTH-1:0] i_host_wdata,
    output logic o_host_wready,

    input logic i_host_renable,
    input logic [ADDR_WIDTH-1:0] i_host_raddr,
    output logic [DATA_WIDTH-1:0] o_host_rdata,
    output logic o_host_valid
);

    localparam int N = MAC_ARRAY_SIZE;

    logic fsm_weight_renable;
    logic [ADDR_WIDTH-1:0] fsm_weight_raddr;
    logic fsm_act_renable;
    logic [ADDR_WIDTH-1:0] fsm_act_raddr;
    logic [N-1:0][N-1:0] fsm_weight_load_mask;
    logic fsm_row_valid;
    logic [$clog2(N)-1:0] fsm_row_fire;
    logic fsm_mac_wenable;
    logic [ADDR_WIDTH-1:0] fsm_mac_waddr;
    logic [$clog2(N)-1:0] fsm_wb_col;

    logic [DATA_WIDTH-1:0] buf_weight_rdata;
    logic buf_weight_valid;
    logic [DATA_WIDTH-1:0] buf_act_rdata;
    logic buf_act_valid;

    logic [DATA_WIDTH-1:0] act_buf [N-1:0];
    logic [DATA_WIDTH-1:0] act_row_out [N-1:0];
    logic act_row_valid;
    logic act_capture_en;
    logic [$clog2(N)-1:0] act_wr_ptr;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n) begin
            act_capture_en <= 1'b0;
            act_wr_ptr <= '0;
            act_buf <= '{default: '0};
            act_row_out <= '{default: '0};
            act_row_valid <= 1'b0;
        end else begin
            act_capture_en <= fsm_act_renable;

            if (act_capture_en) begin
                act_wr_ptr <= act_wr_ptr + 1'd1;
            end else if (!fsm_act_renable && !fsm_row_valid) begin
                act_wr_ptr <= '0;
            end

            if (act_capture_en) begin
                act_buf[act_wr_ptr] <= buf_act_rdata;
            end

            if (fsm_row_valid) begin // ready to push in the act vector
                act_row_out <= act_buf;
                act_row_valid <= 1'b1;
            end else begin
                act_row_valid <= 1'b0;
            end
        end
    end

    logic [N-1:0][N-1:0] weight_load_mask_d1;

    always_ff @(posedge i_clk or negedge i_rst_n) begin
        if (!i_rst_n)
            weight_load_mask_d1 <= '{default: 1'b0};
        else
            weight_load_mask_d1 <= fsm_weight_load_mask;
    end

    logic [DATA_WIDTH-1:0] sds_row_in [N-1:0];
    logic [DATA_WIDTH-1:0] sds_row_out [N-1:0];
    logic [N-1:0] sds_row_valid_out;

    assign sds_row_in = act_row_out;

    systolic_data_setup u_sds_row (
        .i_clk   (i_clk),
        .i_rst_n (i_rst_n),
        .i_valid (act_row_valid),
        .i_data  (sds_row_in),
        .o_data  (sds_row_out),
        .o_valid (sds_row_valid_out)
    );

    logic [DATA_WIDTH-1:0] mac_row_in [N-1:0][N-1:0];
    logic [DATA_WIDTH-1:0] mac_col_in [N-1:0][N-1:0];
    logic [ACC_WIDTH-1:0] mac_acc_in [N-1:0][N-1:0];
    logic [DATA_WIDTH-1:0] mac_row_out [N-1:0][N-1:0];
    logic [DATA_WIDTH-1:0] mac_col_out [N-1:0][N-1:0];
    logic [ACC_WIDTH-1:0] mac_acc_out [N-1:0][N-1:0];

    genvar gi, gj;
    generate
        for (gi = 0; gi < N; gi++) begin : mac_row
            for (gj = 0; gj < N; gj++) begin : mac_col

                if (gj == 0) begin
                    assign mac_row_in[gi][gj] = sds_row_out[gi];
                end else begin
                    assign mac_row_in[gi][gj] = mac_row_out[gi][gj-1];
                end

                if (gi == 0) begin
                    assign mac_col_in[gi][gj] = buf_weight_rdata;
                end else begin
                    assign mac_col_in[gi][gj] = mac_col_out[gi-1][gj];
                end

                if (gi == 0) begin
                    assign mac_acc_in[gi][gj] = '0;
                end else begin
                    assign mac_acc_in[gi][gj] = mac_acc_out[gi-1][gj];
                end

                mac_cell u_mac (
                    .i_clk         (i_clk),
                    .i_rst_n       (i_rst_n),
                    .i_weight_load (weight_load_mask_d1[gi][gj]),
                    .i_row         (mac_row_in[gi][gj]),
                    .i_col         (mac_col_in[gi][gj]),
                    .i_acc         (mac_acc_in[gi][gj]),
                    .o_row         (mac_row_out[gi][gj]),
                    .o_col         (mac_col_out[gi][gj]),
                    .o_acc         (mac_acc_out[gi][gj])
                );
            end
        end
    endgenerate

    logic [ACC_WIDTH-1:0] wb_data;
    always_comb begin
        wb_data = mac_acc_out[N-1][fsm_wb_col];
    end


    tpu_fsm u_fsm (
        .i_clk              (i_clk),
        .i_rst_n            (i_rst_n),
        .i_start            (i_start & ~o_busy),
        .o_done             (o_done),
        .o_busy             (o_busy),

        .o_weight_renable   (fsm_weight_renable),
        .o_weight_raddr     (fsm_weight_raddr),
        .o_act_renable      (fsm_act_renable),
        .o_act_raddr        (fsm_act_raddr),
        .o_weight_load_mask (fsm_weight_load_mask),
        .o_row_valid        (fsm_row_valid),
        .o_row_fire         (fsm_row_fire),
        .o_mac_wenable      (fsm_mac_wenable),
        .o_mac_waddr        (fsm_mac_waddr),
        .o_wb_col           (fsm_wb_col)
    );

    unified_buffer u_buffer (
        .i_clk            (i_clk),
        .i_rst_n          (i_rst_n),

        .i_host_wenable   (i_host_wenable & ~o_busy),
        .i_host_waddr     (i_host_waddr),
        .i_host_wdata     (i_host_wdata),
        .o_host_wready    (o_host_wready),

        .i_host_renable   (i_host_renable & ~o_busy),
        .i_host_raddr     (i_host_raddr),
        .o_host_rdata     (o_host_rdata),
        .o_host_valid     (o_host_valid),

        .i_mac_wenable    (fsm_mac_wenable),
        .i_mac_waddr      (fsm_mac_waddr),
        .i_mac_wdata      (wb_data),

        .i_weight_renable (fsm_weight_renable),
        .i_weight_raddr   (fsm_weight_raddr),
        .o_weight_rdata   (buf_weight_rdata),
        .o_weight_valid   (buf_weight_valid),

        .i_act_renable    (fsm_act_renable),
        .i_act_raddr      (fsm_act_raddr),
        .o_act_rdata      (buf_act_rdata),
        .o_act_valid      (buf_act_valid)
    );

endmodule
