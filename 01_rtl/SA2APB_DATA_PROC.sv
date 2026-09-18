/*
*  
*  Author: Thien Bao Tan  
*  
*  --> Process the accumulated sum of Systolic Array into APB Slave Interface
*
*/

module SA2APB_DATA_PROC #(
    parameter ARRAY_SIZE  = 4,
    parameter MATRIX_DW   = 32,
    parameter SUM_DW      = 32,
    parameter APB_DW      = 32
) (
    // Clock & Reset
    input  wire clk_in,
    input  wire reset_int,
    
    // Output data from Systolic Array
    input  wire [ARRAY_SIZE*SUM_DW-1:0]  result_matrix,
    output reg  [ARRAY_SIZE-1:0] shift_en,

    // Configurable Array Size & Sum DW from APB Interface
    input  wire [5:0] array_size,
    input  wire [1:0] out_matrix_dw,
    
    // Read Request from APB Slave Interface
    input  wire read_req,
    
    // Data & Data Valid for APB Slave Interface
    output reg  matrix_c_valid,
    output reg  [APB_DW-1:0] matrix_c_dout
);
    
    

    // Counter for shifting row and column in Systolic Array
    localparam int MAX_COUNTER_VALUE = ARRAY_SIZE - 1;
    localparam COUNTER_WIDTH     = $clog2(ARRAY_SIZE + 1);
    reg [COUNTER_WIDTH-1:0] counter, row_sel;
    wire counter_reset, row_sel_reset;

    // Temporary data for concatenation if data width is 16
    wire [APB_DW-1:0] temp_data;
    
    // Delay read request
    reg read_req_d;
    always @ (posedge clk_in or negedge reset_int) begin
        if (!reset_int) read_req_d <= '0;
        else read_req_d <= read_req;
    end

    // Counter
    // assign counter_reset = counter == array_size-1; // TODO
    assign counter_reset = counter == (ARRAY_SIZE - 1);
    always @ (posedge clk_in or negedge reset_int) begin
        if (!reset_int) begin
            counter <= 0;
        end
        else if (read_req) begin
            if (counter_reset) begin
                counter <= 0;
            end
            else begin
                counter <= counter + 1;
            end
        end 
    end

    // assign row_sel_reset = row_sel == array_size-1; //TODO
    assign row_sel_reset = row_sel == (ARRAY_SIZE - 1);
    always @ (posedge clk_in or negedge reset_int) begin
        if (!reset_int) begin
            row_sel <= 0;
        end
        else if (read_req) begin
            if (row_sel_reset & counter_reset) begin
                row_sel <= 0;
            end
            else if (counter_reset) begin
                row_sel <= row_sel + 1;
            end
        end
    end

    // Control the shifting in Systolic Array
    assign shift_en = (1 & read_req) << row_sel;
    
    
    assign matrix_c_valid = read_req_d;
    always @ (posedge clk_in or negedge reset_int) begin
        if (!reset_int) begin
            matrix_c_dout <= {APB_DW{1'b0}};
        end
        else if (read_req) begin
            matrix_c_dout <= result_matrix[row_sel * SUM_DW +: SUM_DW];
        end
    end

    // TODO: Eg. 16bit DW merging into 32bit APB
    //generate
    //    if (SUM_DW == 32) begin
    //        always @ (*) begin
    //            // If SUM_DW is 32, then sum dw could be 16 or 32
    //            case (out_matrix_dw)
    //                // DW of SUM is 16bit
    //                1: begin
    //                    matrix_c_dout = {shift_reg[47:32], shift_reg[15:0]};
    //                end
    //                
    //                // DW of SUM is 32bit
    //                2: begin
    //                    matrix_c_dout = shift_reg[SUM_DW-1:0];
    //                end
    //                
    //                // DW of SUM is 32bit
    //                default: begin
    //                    matrix_c_dout = shift_reg[SUM_DW-1:0];
    //                end
    //            endcase
    //        end
    //    end
    //    else if (SUM_DW == 16) begin
    //        always @ (*) begin
    //            temp_data = shift_reg[APB_DW-1:0];
    //        end
    //    end
    //endgenerate

endmodule: SA2APB_DATA_PROC
