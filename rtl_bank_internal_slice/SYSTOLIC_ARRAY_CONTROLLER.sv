`timescale 1ns / 1ps

module SYSTOLIC_ARRAY_CONTROLLER #(
    parameter int unsigned MAX_MATRIX_SIZE = 32,
    parameter int unsigned ARRAY_SIZE      = 8,
    parameter int unsigned M_DIM = ARRAY_SIZE,
    parameter int unsigned K_DIM = ARRAY_SIZE,
    parameter int unsigned N_DIM = ARRAY_SIZE,
    parameter int unsigned MULT_MODE = 0,
    parameter int unsigned RAM_READ_DELAY = 1
) (
    input  logic clk,
    input  logic rst_n,
    input  logic EN,
    input  logic [1:0] mode,

    output logic SA_computen,
    output logic [M_DIM - 1:0] act_fifoen,
    output logic [N_DIM - 1:0] weight_fifoen,
    output logic [2*ARRAY_SIZE - 2 : 0] MAC_en,
    output logic SA_done
);

    localparam logic [1:0] MODE_8BIT  = 1;
    localparam logic [1:0] MODE_16BIT = 2;
    localparam logic [1:0] MODE_32BIT = 3;
    
    localparam int unsigned LAT_MULT  = 1;
    localparam int unsigned LAT_8BIT  = 5;
    localparam int unsigned LAT_16BIT = 9;
    localparam int unsigned LAT_32BIT = 17;
    localparam int unsigned MAX_MAC_LATENCY = LAT_32BIT;
    localparam int unsigned DIAG_NUM = 2 * ARRAY_SIZE - 1;
    localparam int unsigned TOTAL_STEPS = MAX_MATRIX_SIZE + DIAG_NUM - 1;
    localparam int unsigned PHASE_W = $clog2(MAX_MAC_LATENCY);
    localparam int unsigned STEP_W = $clog2(TOTAL_STEPS);

    logic [PHASE_W-1:0] phase_cnt;
    logic [STEP_W-1:0]  step_cnt;
    logic [PHASE_W-1:0] latency_last_q;

    logic [2*ARRAY_SIZE - 2 : 0] MAC_en_raw;

    typedef enum logic [1:0] {
        IDLE = 2'd0,
        RUN  = 2'd1,
        DONE = 2'd2
    } state_t;
    state_t state, next_state;

    logic en_armed;
    logic start_fire;

    assign start_fire = (state == IDLE) && EN && en_armed;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            en_armed <= 1'b1;
        end else begin
            if (!EN) begin
                en_armed <= 1'b1;
            end else if (start_fire) begin
                en_armed <= 1'b0;
            end
        end
    end

    function automatic logic [PHASE_W-1:0] get_latency_last(
        input logic       mult_mode_in,
        input logic [1:0] mode_in
    );
        if (mult_mode_in) begin
            get_latency_last = LAT_MULT - 1;
        end else begin
            unique case (mode_in)
                MODE_8BIT:  get_latency_last = LAT_8BIT  - 1;
                MODE_16BIT: get_latency_last = LAT_16BIT - 1;
                MODE_32BIT: get_latency_last = LAT_32BIT - 1;
                default:    get_latency_last = LAT_32BIT - 1;
            endcase
        end
    endfunction

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            latency_last_q <= LAT_32BIT - 1;
        end else if (start_fire) begin
            latency_last_q <= get_latency_last(MULT_MODE, mode);
        end
    end

    logic phase_last;
    logic step_last;
    logic step_pulse;

    assign phase_last = (phase_cnt == latency_last_q);
    assign step_last  = (step_cnt  == (TOTAL_STEPS - 1));

    assign step_pulse = (phase_cnt == '0);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_cnt <= '0;
            step_cnt  <= '0;
        end else if (state != next_state) begin
            phase_cnt <= '0;
            step_cnt  <= '0;
        end else begin
            unique case (state)

                RUN: begin
                    if (phase_last) begin
                        phase_cnt <= '0;

                        if (!step_last) begin
                            step_cnt <= step_cnt + 1'b1;
                        end
                    end else begin
                        phase_cnt <= phase_cnt + 1'b1;
                    end
                end

                default: begin
                    phase_cnt <= '0;
                    step_cnt  <= '0;
                end

            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;

        unique case (state)

            IDLE: begin
                if (start_fire) begin
                    next_state = RUN;
                end
            end

            RUN: begin
                if (step_last && phase_last) begin
                    next_state = DONE;
                end
            end

            DONE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end

        endcase
    end

    always_comb begin
        SA_computen   = 1'b0;
        act_fifoen    = '0;
        weight_fifoen = '0;
        MAC_en_raw    = '0;
        SA_done       = 1'b0;

        unique case (state)

            IDLE: begin
            end

            RUN: begin
                SA_computen = 1'b1;

                if (step_pulse) begin

                    for (int unsigned i = 0; i < M_DIM; i++) begin
                        if ((step_cnt >= i) &&
                            (step_cnt <  i + MAX_MATRIX_SIZE)) begin
                            act_fifoen[i] = 1'b1;
                            weight_fifoen[i] = 1'b1;
                        end
                    end

                    for (int unsigned d = 0; d < DIAG_NUM; d++) begin
                        if ((step_cnt >= d) &&
                            (step_cnt <  d + MAX_MATRIX_SIZE)) begin
                            MAC_en_raw[d] = 1'b1;
                        end
                    end
                end
            end

            DONE: begin
                SA_done = 1'b1;
            end

            default: begin
            end

        endcase
    end

    generate
        if (RAM_READ_DELAY == 0) begin : gen_mac_en_no_delay

            always_comb begin
                MAC_en = MAC_en_raw;
            end

        end else begin : gen_mac_en_delay

            logic [RAM_READ_DELAY-1:0][2*ARRAY_SIZE - 2 : 0] MAC_en_delay_q;

            always_ff @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    MAC_en_delay_q <= '0;
                end else begin
                    MAC_en_delay_q[0] <= MAC_en_raw;

                    for (int unsigned j = 1; j < RAM_READ_DELAY; j++) begin
                        MAC_en_delay_q[j] <= MAC_en_delay_q[j-1];
                    end
                end
            end

            always_comb begin
                MAC_en = MAC_en_delay_q[RAM_READ_DELAY-1];
            end

        end
    endgenerate

endmodule
