/*
*  
*  Author: Thien Bao Tan  
*  
*  Reference: https://github.com/Dazhuzhu-github/systolic-array  
*  --> Take wrapper of Systolic Array as reference
*  --> Improvement: parameterize the data width of Matrices' elements
*  --> Accumulated value is shifted to the neighbouring MAC
*/

module MAC_ROW #(
    parameter ARRAY_SIZE  = 4,
    parameter MATRIX_DW   = 32,
    parameter SUM_DW      = 32,
    parameter MULT_MODE   = 0
) (
    // Interface: Clock
    input  wire clk_in,

    // Interface: Reset
    input  wire reset_int,

    // Interface: Matrix Inputs
    input  wire signed [MATRIX_DW-1:0]     left_din,
    input  wire [ARRAY_SIZE*MATRIX_DW-1:0] top_din,
    
    // Interface: Matrix Output
    output reg  [ARRAY_SIZE*MATRIX_DW-1:0] down_dout,

    //Interface: Accumulators Output
    output reg  [SUM_DW-1:0]               sum_out,

    //Interface: Control & Status Signals
    input  wire [ARRAY_SIZE-1:0]           enable,
    input  wire                            shift_en,
    input  wire [1:0]                      mode
);
    
    wire [(ARRAY_SIZE-1)*MATRIX_DW-1:0] row_wire;
    wire [(ARRAY_SIZE-1)*SUM_DW-1:0]    sum_wire;

    genvar col;
    generate
        // Construct a row of `ARRAY_SIZE` number of MAC Units
        for(col = 0; col < ARRAY_SIZE; col = col + 1) begin: mac_gen
            // First MAC unit of the row
            if (col == 0) begin
                MAC #(
                      .MATRIX_DW(MATRIX_DW),
                      .SUM_DW(SUM_DW),
                      .MULT_MODE(MULT_MODE)
                     ) u_MAC (
                       .clk_in    (clk_in),
                       .reset_int (reset_int),
                       .enable    (enable[col]),
                       .shift_en  (shift_en),
                       .mode      (mode),
                       .top_din   (top_din[MATRIX_DW*col +: MATRIX_DW]),
                       .down_dout (down_dout[MATRIX_DW*col +: MATRIX_DW]),
                       .left_din  (left_din), // DIFFERENCE
                       .right_dout(row_wire[MATRIX_DW*col +: MATRIX_DW]),
                       .shift_in  (sum_wire[SUM_DW*col +: SUM_DW]), // DIFFERENCE
                       .sum_out   (sum_out) // DIFFERENCE
                     );
            end
            else if (col == (ARRAY_SIZE-1)) begin
                MAC #(
                      .MATRIX_DW(MATRIX_DW),
                      .SUM_DW(SUM_DW),
                      .MULT_MODE(MULT_MODE)
                     ) u_MAC (
                       .clk_in    (clk_in),
                       .reset_int (reset_int),
                       .enable    (enable[col]),
                       .shift_en  (shift_en),
                       .mode      (mode),
                       .top_din   (top_din[MATRIX_DW*col +: MATRIX_DW]),
                       .down_dout (down_dout[MATRIX_DW*col +: MATRIX_DW]),
                       .left_din  (row_wire[MATRIX_DW*(col-1) +: MATRIX_DW]), // DIFFERENCE
                       .right_dout(), // DIFFERENCE
                       .shift_in  ({SUM_DW{1'b0}}), // DIFFERENCE
                       .sum_out   (sum_wire[SUM_DW*(col-1) +: SUM_DW]) // DIFFERENCE
                     );
            end 
            // Other MAC units of the row
            else begin
                MAC #(
                      .MATRIX_DW(MATRIX_DW),
                      .SUM_DW(SUM_DW),
                      .MULT_MODE(MULT_MODE)
                     ) u_MAC (
                       .clk_in    (clk_in),
                       .reset_int (reset_int),
                       .enable    (enable[col]),
                       .shift_en  (shift_en),
                       .mode      (mode),
                       .top_din   (top_din[MATRIX_DW*col +: MATRIX_DW]),
                       .down_dout (down_dout[MATRIX_DW*col +: MATRIX_DW]),
                       .left_din  (row_wire[MATRIX_DW*(col-1) +: MATRIX_DW]), // DIFFERENCE
                       .right_dout(row_wire[MATRIX_DW*col +: MATRIX_DW]),
                       .shift_in  (sum_wire[SUM_DW*col +: SUM_DW]), // DIFFERENCE
                       .sum_out   (sum_wire[SUM_DW*(col-1) +: SUM_DW]) // DIFFERENCE
                     );
            end
        end
    endgenerate

endmodule: MAC_ROW

module SYSTOLIC_ARRAY #(
    parameter ARRAY_SIZE = 4,
    parameter MATRIX_DW  = 32,
    parameter SUM_DW     = 32,
    parameter MULT_MODE  = 0
) (
    // Interface: Clock
    input  wire clk_in,

    // Interface: Reset
    input  wire reset_int,
    
    //Interface: Control & Status Signals
    input  wire [ARRAY_SIZE*2-2:0]         enable,
    input  wire [ARRAY_SIZE-1:0]           shift_en,
    input  wire [1:0]                      mode,

    // Interface: Matrix Inputs
    input  wire [ARRAY_SIZE*MATRIX_DW-1:0] matrix_a_din,
    input  wire [ARRAY_SIZE*MATRIX_DW-1:0] matrix_b_din,

    //Interface: Accumulators Output
    output reg  [ARRAY_SIZE*SUM_DW-1:0]    result_matrix
);

    wire [ARRAY_SIZE*ARRAY_SIZE*MATRIX_DW-1:0] col_wire;

    genvar row;
    generate
      // Construct `ARRAY_SIZE` number of MAC Rows
         for (row = 0; row < ARRAY_SIZE; row = row + 1) begin: mac_row_gen
          if (row == 0) begin
              MAC_ROW #(
                      .ARRAY_SIZE(ARRAY_SIZE),
                      .MATRIX_DW(MATRIX_DW),
                      .SUM_DW(SUM_DW),
                      .MULT_MODE(MULT_MODE)
                      ) u_MAC_ROW (
                        .clk_in    (clk_in),
                        .reset_int (reset_int),
                        .enable    (enable[row+:ARRAY_SIZE]),
                        .shift_en  (shift_en[row]),
                        .mode      (mode),
                        .top_din   (matrix_b_din), // DIFFERENCE
                        .down_dout (col_wire[ARRAY_SIZE*MATRIX_DW*row +: ARRAY_SIZE*MATRIX_DW]),
                        .left_din  (matrix_a_din[MATRIX_DW*row +: MATRIX_DW]),
                        .sum_out   (result_matrix[SUM_DW*row +: SUM_DW])
                      );
          end else begin
              MAC_ROW #(
                      .ARRAY_SIZE(ARRAY_SIZE),
                      .MATRIX_DW(MATRIX_DW),
                      .SUM_DW(SUM_DW),
                      .MULT_MODE(MULT_MODE)
                      ) u_MAC_ROW (
                        .clk_in    (clk_in),
                        .reset_int (reset_int),
                        .enable    (enable[row+:ARRAY_SIZE]),
                        .shift_en  (shift_en[row]),
                        .mode      (mode),
                        .top_din   (col_wire[ARRAY_SIZE*MATRIX_DW*(row-1) +: ARRAY_SIZE*MATRIX_DW]), // DIFFERENCE
                        .down_dout (col_wire[ARRAY_SIZE*MATRIX_DW*row +: ARRAY_SIZE*MATRIX_DW]),
                        .left_din  (matrix_a_din[MATRIX_DW*row +: MATRIX_DW]),
                        .sum_out   (result_matrix[SUM_DW*row +: SUM_DW])
                      );
          
          end
         end
    endgenerate

endmodule: SYSTOLIC_ARRAY
