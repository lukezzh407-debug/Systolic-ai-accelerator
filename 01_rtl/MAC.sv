/*
 * Author: Ruoxin Zhao
 *
 * Note:
 * Some parts of this code were refined with AI assistance.
 * The main design decisions, implementation, and verification were completed and reviewed by the author.
 */
 
module MAC #(
    parameter MATRIX_DW = 32,
    parameter SUM_DW    = 32,
    parameter MULT_MODE = 1    // 1: combinational multiplier, 0: iterative Radix-4 Booth
) (
    // Clock and reset
    input  logic clk_in,
    input  logic reset_int,

    // Matrix inputs
    input  logic signed [MATRIX_DW-1:0] left_din,
    input  logic signed [MATRIX_DW-1:0] top_din,
    
    // Matrix outputs to neighboring MACs
    output logic signed [MATRIX_DW-1:0] right_dout,
    output logic signed [MATRIX_DW-1:0] down_dout,

    // Accumulator shift input/output
    input  logic signed [SUM_DW-1:0] shift_in,
    output logic signed [SUM_DW-1:0] sum_out,

    // Control signals
    input  logic       enable,     // one-cycle start pulse for one MAC operation
    input  logic       shift_en,   // load shifted accumulated value
    input  logic [1:0] mode        // 1: 8-bit, 2: 16-bit, 3: 32-bit
);

    generate

        // Combinational multiplication
        if (MULT_MODE == 1) begin: comb_mult

            logic signed [(2*MATRIX_DW)-1:0] product;

            assign product = left_din * top_din;
            
            always_ff @(posedge clk_in or negedge reset_int) begin
                if (!reset_int) begin
                    right_dout <= '0;
                    down_dout  <= '0;
                    sum_out    <= '0;
                end
                else if (shift_en) begin
                    sum_out <= shift_in;
                end
                else if (enable) begin
                    right_dout <= left_din;
                    down_dout  <= top_din;
                    sum_out    <= sum_out + product[SUM_DW-1:0];
                end
            end

        end

        // Multi-cycle iterative Radix-4 Booth multiplication
        else if (MULT_MODE == 0) begin: booth_mult

            localparam int MAX_ITER = MATRIX_DW / 2;
            localparam int ITER_W   = $clog2(MAX_ITER + 1);

            logic busy;

            logic signed [MATRIX_DW-1:0] a_reg;
            logic signed [MATRIX_DW-1:0] b_reg;

            logic [MATRIX_DW:0] b_ext_reg;

            logic signed [2*MATRIX_DW:0] a_ext;
            logic signed [2*MATRIX_DW:0] pp_base;
            logic signed [2*MATRIX_DW:0] pp_shifted;
            logic signed [2*MATRIX_DW:0] acc_reg;
            logic signed [2*MATRIX_DW:0] acc_next;

            logic [ITER_W-1:0] iter_cnt;
            logic [ITER_W-1:0] max_iter;
            logic [2:0]        booth_bits;

            // Mode only controls the number of Booth iterations.
            // mode = 1: 8-bit, mode = 2: 16-bit, mode = 3: 32-bit
            always_comb begin
                case (mode)
                    2'd1:    max_iter = 4;   // 8-bit mode
                    2'd2:    max_iter = 8;   // 16-bit mode
                    2'd3:    max_iter = 16;  // 32-bit mode
                    default: max_iter = 16;  // default to 32-bit mode
                endcase
            end

            // Sign-extend multiplicand for Booth partial product generation.
            always_comb begin
                a_ext = {{(MATRIX_DW+1){a_reg[MATRIX_DW-1]}}, a_reg};
            end

            // Current Booth encoding bits.
            always_comb begin
                booth_bits = b_ext_reg[2*iter_cnt +: 3];
            end

            // Generate one Booth partial product.
            always_comb begin
                case (booth_bits)
                    3'b000,
                    3'b111: begin
                        pp_base = '0;
                    end

                    3'b001,
                    3'b010: begin
                        pp_base = a_ext;
                    end

                    3'b011: begin
                        pp_base = a_ext <<< 1;
                    end

                    3'b100: begin
                        pp_base = -(a_ext <<< 1);
                    end

                    3'b101,
                    3'b110: begin
                        pp_base = -a_ext;
                    end

                    default: begin
                        pp_base = '0;
                    end
                endcase

                pp_shifted = pp_base <<< (2 * iter_cnt);
                acc_next   = acc_reg + pp_shifted;
            end

            always_ff @(posedge clk_in or negedge reset_int) begin
                if (!reset_int) begin
                    right_dout <= '0;
                    down_dout  <= '0;
                    sum_out    <= '0;

                    busy       <= 1'b0;
                    a_reg      <= '0;
                    b_reg      <= '0;
                    b_ext_reg  <= '0;
                    acc_reg    <= '0;
                    iter_cnt   <= '0;
                end
                else begin
                    // Load shifted accumulated value when not busy.
                    if (shift_en && !busy) begin
                        sum_out <= shift_in;
                    end

                    // Start one iterative Booth multiplication.
                    else if (enable && !busy) begin
                        a_reg     <= left_din;
                        b_reg     <= top_din;
                        b_ext_reg <= {top_din, 1'b0};

                        acc_reg   <= '0;
                        iter_cnt  <= '0;
                        busy      <= 1'b1;
                    end

                    // Run iterative Radix-4 Booth multiplication.
                    else if (busy) begin
                        acc_reg <= acc_next;

                        if (iter_cnt == max_iter - 1) begin
                            busy <= 1'b0;

                            right_dout <= a_reg;
                            down_dout  <= b_reg;

                            sum_out <= sum_out + acc_next[SUM_DW-1:0];
                        end
                        else begin
                            iter_cnt <= iter_cnt + 1'b1;
                        end
                    end
                end
            end

        end

    endgenerate

endmodule: MAC
