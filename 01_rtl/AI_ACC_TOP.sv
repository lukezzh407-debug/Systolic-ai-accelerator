/*
  Contributors:
    * Matti Käyrä (matti.kayra@tuni.fi)
    * SyoSil
  Description:
    * example student area rtl code with off chip gpio interface
    * original interface created with kactus2. Do not rewrite from kactus.
    * Modified version of student_ss_example.sv
*/

module AI_ACC_TOP #(
    parameter APB_AW          = 10,
    parameter APB_DW          = 32,
    parameter MATRIX_SIZE     = 32,
    parameter ARRAY_SIZE      = 4,
    parameter MATRIX_DW       = 32,
    parameter SUM_DW          = 32,
    parameter MAC_LATENCY     = 32,
    parameter RAM_READ_DELAY  = 1,
    parameter MULT_MODE       = 0,
    parameter NUM_GPIO        = 16
) (
    // Interface: APB
    input  wire [APB_AW-1:0]   PADDR,
    input  wire                PENABLE,
    input  wire                PSEL,
    input  wire [APB_DW-1:0]   PWDATA,
    input  wire                PWRITE,
    input  wire [APB_DW/8-1:0] PSTRB,
    output reg  [APB_DW-1:0]   PRDATA,
    output reg                 PREADY,
    output reg                 PSLVERR,

    // Interface: Clock
    input  wire                clk_in,

    // Interface: IRQ
    output reg                 irq,

    // Interface: Reset
    input  wire                reset_int,

    // Interface: ss_ctrl
    input logic                irq_en,
    input logic [7:0]          ss_ctrl,

    //Interface: GPIO
    input  wire [NUM_GPIO-1:0] pmod_gpi,
    output reg  [NUM_GPIO-1:0] pmod_gpio_oe,
    output reg  [NUM_GPIO-1:0] pmod_gpo
);
    
    localparam ARRAY_SIZE_LEN = 6; // TODO: scale to ARRAY_SIZE?

    wire                             controller_start;
    wire [ARRAY_SIZE-1:0]            act_fifo_rd_en;
    wire [ARRAY_SIZE-1:0]            wei_fifo_rd_en;

    wire [ARRAY_SIZE_LEN-1:0]        sys_arr_array_size;
    wire [1:0]                       sys_arr_in_data_width;
    wire [1:0]                       sys_arr_out_data_width;
    wire                             sys_arr_read_req;
    wire [2*ARRAY_SIZE - 2 : 0]      sys_arr_enable;
    wire [ARRAY_SIZE-1:0]            sys_arr_shift_en;
    wire                             sys_arr_done;
  
    wire [ARRAY_SIZE*MATRIX_DW-1:0]  matrix_a_din;
    wire [ARRAY_SIZE*MATRIX_DW-1:0]  matrix_b_din;
    wire [ARRAY_SIZE*SUM_DW-1:0]     result_matrix;
    wire [APB_DW-1:0]                matrix_c_dout;

    //================================================================================
    // APB & FIFO MODULE
    //--------------------------------------------------------------------------------
    BUFFER_WRAPPER_SR #(
                .ARRAY_SIZE       (ARRAY_SIZE),
                .SRAM_DEPTH       (MATRIX_SIZE),
                .MATRIX_DW        (MATRIX_DW),
                .SUM_DW           (SUM_DW),
                .APB_AW           (APB_AW),
                .APB_DW           (APB_DW)
              ) u_APB_SRAM_WRAPPER (
                  .pclk               (clk_in), 
                  .prst_n             (reset_int), 
                  .psel               (PSEL), 
                  .penable            (PENABLE), 
                  .pwrite             (PWRITE), 
                  .paddr              (PADDR), 
                  .pwr_data           (PWDATA), 
                  .pready             (PREADY), 
                  .prd_data           (PRDATA),
                  .pslverr            (PSLVERR),
                  // TODO: Missing PSTRB and PSLVERR function
                  
                  .array_size         (sys_arr_array_size),
                  .matrix_dw          (sys_arr_in_data_width),
                  .sum_dw             (sys_arr_out_data_width),
                  
                  .compute_en         (controller_start),
                  .ctrl_act_fifoen    (act_fifo_rd_en),
                  .ctrl_wei_fifoen    (wei_fifo_rd_en),
                  .sa_done            (sys_arr_done),
                  
                  .matrix_act_din     (matrix_a_din), 
                  .matrix_wei_din     (matrix_b_din),
                  
                  .sa_out_rd_en       (sys_arr_read_req),
                  .matrix_c_dout      (matrix_c_dout),
                  .matrix_c_valid     (matrix_c_valid)
    );

    //================================================================================
    // SYSTOLIC ARRAY CONTROLLER
    // TODO: Simplify parameters
    //--------------------------------------------------------------------------------
    SYSTOLIC_ARRAY_CONTROLLER #(
                .MAX_MATRIX_SIZE  (MATRIX_SIZE),
                .ARRAY_SIZE       (ARRAY_SIZE),
                .M_DIM            (ARRAY_SIZE),
                .K_DIM            (ARRAY_SIZE),
                .N_DIM            (ARRAY_SIZE),
                .MULT_MODE        (MULT_MODE),
                .RAM_READ_DELAY   (RAM_READ_DELAY)
              ) u_SYSTOLIC_ARRAY_CONTROLLER (
                  .clk             (clk_in),
                  .rst_n           (reset_int),
                  .EN              (controller_start),
                  .SA_computen     (),
                  .mode            (sys_arr_out_data_width),
                  .act_fifoen      (act_fifo_rd_en),
                  .weight_fifoen   (wei_fifo_rd_en),
                  .MAC_en          (sys_arr_enable),
                  .SA_done         (sys_arr_done)
    );
    
    //================================================================================
    // SYSTOLIC ARRAY
    //--------------------------------------------------------------------------------
    SYSTOLIC_ARRAY #(
                .ARRAY_SIZE       (ARRAY_SIZE),
                .MATRIX_DW        (MATRIX_DW),
                .SUM_DW           (SUM_DW),
                .MULT_MODE        (MULT_MODE)
              ) u_SYSTOLIC_ARRAY (
                  .clk_in          (clk_in),
                  .reset_int       (reset_int),
                  .enable          (sys_arr_enable),
                  .shift_en        (sys_arr_shift_en),
                  .matrix_a_din    (matrix_a_din), // From Activation FIFO
                  .matrix_b_din    (matrix_b_din), // From Weight FIFO
                  .result_matrix   (result_matrix),                          
                  .mode            (sys_arr_out_data_width)  
    );

    //================================================================================
    // SA2APB DATA PROCESS
    //--------------------------------------------------------------------------------
    SA2APB_DATA_PROC #(
                .ARRAY_SIZE       (ARRAY_SIZE),
                .MATRIX_DW        (MATRIX_DW),
                .SUM_DW           (SUM_DW),
                .APB_DW           (APB_DW)
              ) u_SA2APB_DATA_PROC (
                  .clk_in          (clk_in),
                  .reset_int       (reset_int),
                  .array_size      (sys_arr_array_size),
                  .out_matrix_dw   (sys_arr_out_data_width),
                  .shift_en        (sys_arr_shift_en),
                  .result_matrix   (result_matrix),
                  .read_req        (sys_arr_read_req),
                  .matrix_c_dout   (matrix_c_dout),               
                  .matrix_c_valid  (matrix_c_valid)               
    );               

  
    //================================================================================
    // PMOD CONTROLLER
    //--------------------------------------------------------------------------------


endmodule

//    // Registers
//    logic PSLVERR_reg;
//    logic [31:0] PRDATA_reg;
//    logic PREADY_reg;
//
//    logic [31:0] RW_REG;
//    logic [31:0] GPIO_R_REG;
//    logic [31:0] GPIO_W_REG;
//    logic [31:0] SS_CTRL_REG;
//
//    logic IRQ_REG;
//    logic [15:0] COUNT_REG;
//
//    always_ff @(posedge clk_in or negedge reset_int)
//    begin: output_w_r
//        if (~reset_int) begin
//            PSLVERR_reg <=1'b0;
//            PRDATA_reg  <='d0;
//            PREADY_reg  <=1'b0;
//
//            RW_REG <= 32'd0;
//            GPIO_R_REG <= 32'd0;
//            GPIO_W_REG <= 32'd0;
//            IRQ_REG <= 32'd0;
//            SS_CTRL_REG <= 32'd0;
//            COUNT_REG <= 32'd0;
//
//            pmod_0_gpio_oe <= 4'h0;
//            pmod_1_gpio_oe <= 4'h0;
//        end
//        else begin
//            if(PSEL) begin
//                //if access already happened, cut the response signals
//                if (PREADY_reg == 1 && PSLVERR_reg == 1) begin
//                    PSLVERR_reg <= 1'b0;
//                    // error signal does not require it's own process as it
//                    // can't be without ready
//                    PREADY_reg <= 1'b0;
//                end
//                else if (PREADY_reg == 1) begin
//                    PREADY_reg <= 1'b0;
//                end
//                else if(PWRITE) begin   // write
//                    if(PADDR == 0) begin
//                        RW_REG <= PWDATA;
//                        PSLVERR_reg <= 1'b0;
//                        PREADY_reg  <= 1'b1;
//                    end
//                    else if (PADDR == 8) begin
//                        GPIO_W_REG <= PWDATA;
//                        PSLVERR_reg <= 1'b0;
//                        PREADY_reg  <= 1'b1;
//                        pmod_0_gpio_oe <= 4'hf;
//                        pmod_1_gpio_oe <= 4'hf;
//                    end
//                    else if (PADDR == 12) begin
//                        SS_CTRL_REG <= PWDATA;
//                        PSLVERR_reg <= 1'b0;
//                        PREADY_reg  <= 1'b1;
//                    end
//                    else begin          // psel
//                        PSLVERR_reg <= 1'b1;
//                        PREADY_reg  <= 1'b1;
//                    end
//                end
//                else begin              // read
//                    if(PADDR == 0) begin
//                        PRDATA_reg <= RW_REG;
//                        PSLVERR_reg <= 1'b0;
//                        PREADY_reg  <= 1'b1;
//                    end
//                    else if(PADDR == 4) begin
//                        PRDATA_reg <= GPIO_R_REG;
//                        PSLVERR_reg <= 1'b0;
//                        PREADY_reg  <= 1'b1;
//                        pmod_0_gpio_oe <= 4'h0;
//                        pmod_1_gpio_oe <= 4'h0;
//                    end
//                    else if(PADDR == 12) begin
//                        PRDATA_reg <= SS_CTRL_REG;
//                        PSLVERR_reg <= 1'b0;
//                        PREADY_reg  <= 1'b1;
//                    end
//                    else begin
//                        PSLVERR_reg <= 1'b1;
//                        PREADY_reg  <= 1'b1;
//                    end
//                end
//            end
//            else begin // psel
//                PSLVERR_reg <= 1'b0;
//                PREADY_reg  <= 1'b0;
//            end
//
//            // Update GPIO Registers according to PMOD output enable
//            if (pmod_0_gpio_oe == 4'h0) begin
//                GPIO_R_REG[3:0] <= pmod_0_gpi;
//            end
//            if (pmod_0_gpio_oe == 4'h0) begin
//                GPIO_R_REG[7:4] <= pmod_1_gpi;
//            end
//
//            SS_CTRL_REG[7:0] <= ss_ctrl_4;
//
//            // enable interrupt using IRQ_REG or update COUNT_REG
//            if (irq_4 == 1'b0 && COUNT_REG >= 16'hA00) begin
//                IRQ_REG <= 1'b1;
//                COUNT_REG <= 32'h0;
//            end else if (irq_4 == 1) begin
//                IRQ_REG <= 32'h0;
//            end else begin
//                COUNT_REG <= pmod_0_gpi + COUNT_REG;
//            end
//        end
//
//    end
//
//    always_comb begin: output_assignment
//
//        PSLVERR = PSLVERR_reg;
//        PRDATA  = PRDATA_reg;
//        PREADY  = PREADY_reg;
//
//        // set irq pin high only if irq_en
//        irq_4 = (IRQ_REG & irq_en_4);
//
//        // Update GPO pins according to PMOD output enable
//        if (pmod_0_gpio_oe == 4'hf) begin
//            pmod_0_gpo = GPIO_W_REG [3:0];
//        end
//
//        if (pmod_0_gpio_oe == 4'hf) begin
//            pmod_1_gpo = GPIO_W_REG [7:4];
//        end
//
//    end
//
//
///////// SVA /////////
//`ifndef SYNTHESIS
//// insert here unsynthesizeable verification assertions.
//`endif

