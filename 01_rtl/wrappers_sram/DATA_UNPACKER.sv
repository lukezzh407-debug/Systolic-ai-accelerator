`timescale 1ns / 1ps

module DATA_UNPACKER #(
    parameter APB_DW = 32
)(
    input  logic              pclk,
    input  logic              prst_n,
    
    // configuration inputs
    input  logic [1:0]        matrix_dw,
    input  logic [APB_DW-1:0] pwr_data,
    
    // bus control and status signals
    input  logic              apb_write_valid,
    input  logic              sel_act,
    input  logic              sel_wei,
    input  logic              pslverr,
    input  logic              psel,
    
    // data outputs and ready signal
    output logic [31:0]       current_unpack_data,
    output logic              unpack_ready
);

    // unpacking times for different data widths
    logic [2:0] unpack_tot; 
    always_comb begin
        case(matrix_dw)
            2'b00: unpack_tot = 3'd7; // 4-bit
            2'b01: unpack_tot = 3'd3; // 8-bit
            2'b10: unpack_tot = 3'd1; // 16-bit
            2'b11: unpack_tot = 3'd0; // 32-bit
            default: unpack_tot = 3'd0;
        endcase
    end

    // status reg 
    logic        is_unpacking;
    logic [2:0]  unpack_cnt;
    logic [31:0] unpack_buf;
    
    //  data division and Sign Extension
    always_comb begin
        if (is_unpacking) begin
            case(matrix_dw)
                2'b00: current_unpack_data = {{28{unpack_buf[3]}},  unpack_buf[3:0]};
                2'b01: current_unpack_data = {{24{unpack_buf[7]}},  unpack_buf[7:0]};
                2'b10: current_unpack_data = {{16{unpack_buf[15]}}, unpack_buf[15:0]};
                default: current_unpack_data = unpack_buf;
            endcase
        end else begin // the first data to unpack comes directly from pwr_data
            case(matrix_dw)
                2'b00: current_unpack_data = {{28{pwr_data[3]}},  pwr_data[3:0]};
                2'b01: current_unpack_data = {{24{pwr_data[7]}},  pwr_data[7:0]};
                2'b10: current_unpack_data = {{16{pwr_data[15]}}, pwr_data[15:0]};
                default: current_unpack_data = pwr_data;
            endcase
        end
    end

    // data shifting and unpacking control
    always_ff @(posedge pclk or negedge prst_n) begin
        if (!prst_n) begin
            is_unpacking <= 1'b0;
            unpack_cnt   <= '0;
            unpack_buf   <= '0;
        end else begin
            if (apb_write_valid && (sel_act || sel_wei) && !is_unpacking && unpack_tot > 0 && !pslverr) begin
                is_unpacking <= 1'b1;
                unpack_cnt   <= unpack_tot;
                case(matrix_dw)
                    2'b00: unpack_buf <= {4'd0,  pwr_data[31:4]};
                    2'b01: unpack_buf <= {8'd0,  pwr_data[31:8]};
                    2'b10: unpack_buf <= {16'd0, pwr_data[31:16]};
                    default: unpack_buf <= pwr_data;
                endcase
            end 
            else if (is_unpacking && !pslverr) begin
                if (unpack_cnt > 1) begin
                    unpack_cnt <= unpack_cnt - 1;
                    case(matrix_dw)
                        2'b00: unpack_buf <= {4'd0,  unpack_buf[31:4]};
                        2'b01: unpack_buf <= {8'd0,  unpack_buf[31:8]};
                        2'b10: unpack_buf <= {16'd0, unpack_buf[31:16]};
                        default: unpack_buf <= unpack_buf;
                    endcase
                end else begin
                    is_unpacking <= 1'b0; 
                end
            end
            
            if (!psel) begin
                is_unpacking <= 1'b0;
            end
        end
    end

    // ready signal to the bus, 32bit without unpacking(always ready), 4/8/16bits 
    assign unpack_ready = (unpack_tot == 0) || (is_unpacking && unpack_cnt == 1);

endmodule