/*
  Contributors:
    * Matti Käyrä (matti.kayra@tuni.fi)
  Description:
    * integration tieoff
*/

module tum_ss (
    // Interface: APB
    input  logic [31:0] PADDR,
    input  logic        PENABLE,
    input  logic        PSEL,
    input  logic [31:0] PWDATA,
    input  logic        PWRITE,
    output logic [31:0] PRDATA,
    output logic        PREADY,
    output logic        PSLVERR,

    // Interface: Clock
    input  logic        clk_in,

    // Interface: high_speed_clock
    input  logic        high_speed_clk,

    // Interface: IRQ
    output logic        irq_3,

    // Interface: Reset
    input  logic        reset_int,

    // Interface: SS_Ctrl
    input  logic        irq_en_3,
    input  logic [7:0]  ss_ctrl_3,
    
    //Interface: GPIO pmod 
    input  logic [15:0]  pmod_gpi,
    output logic [15:0]  pmod_gpo,
    output logic [15:0]  pmod_gpio_oe

);

    assign pmod_gpo = 0;
    assign irq_3 = 0;

    AI_ACC_TOP #(
                 .APB_AW(12),
                 .APB_DW(32),
                 .MATRIX_SIZE(32),
                 .ARRAY_SIZE(8),
                 .MATRIX_DW(32),
                 .SUM_DW(32),
                 .MAC_LATENCY(16),
                 .RAM_READ_DELAY(1),
                 .MULT_MODE(0)
                 // Other parameters
                ) u_AI_ACC_TOP (
                    .clk_in				   (clk_in),
                    .reset_int			 (reset_int),
                    .PADDR				   (PADDR),
                    .PENABLE			   (PENABLE),
                    .PSEL				     (PSEL),
                    .PWDATA				   (PWDATA),
                    .PWRITE				   (PWRITE),
                    .PSTRB				   (4'hF),
                    .PRDATA				   (PRDATA),
                    .PREADY				   (PREADY),
                    .PSLVERR			   (PSLVERR), 
                    .irq  				   (),
                    .irq_en 				 (irq_en_3),
                    .ss_ctrl  			 (ss_ctrl_3),
                    .pmod_0_gpi			 (0),
                    .pmod_0_gpo			 (),
                    .pmod_0_gpio_oe	 (),
                    .pmod_1_gpi			 (0),
                    .pmod_1_gpo			 (),
                    .pmod_1_gpio_oe  () 
                );

endmodule
