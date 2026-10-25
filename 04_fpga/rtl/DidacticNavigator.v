module DidacticNavigator (
  // Interface: Clock
    input  wire                         clk_in,

    // Interface: GPIO
    inout  wire          [15:0]         gpio,

    //// Interface: JTAG
    //inout  wire                         jtag_tck,
    //inout  wire                         jtag_tdi,
    //inout  wire                         jtag_tdo,
    //inout  wire                         jtag_tms,
    //inout  wire                         jtag_trst,

    // Interface: Reset
    inout  wire                         reset,

    // Interface: SPI
    inout  wire          [1:0]          spi_csn,
    inout  wire          [3:0]          spi_data,
    inout  wire                         spi_sck,

    // Interface: UART
    inout  wire                         uart_rx,
    inout  wire                         uart_tx

);

  // ----------------------------------------------------------------
  // 1. Internal Wires for the BSCANE2 JTAG Tunnel
  // ----------------------------------------------------------------
  wire bscan_tck;
  wire bscan_tdi;
  wire bscan_tdo; // Output from your SoC, Input to BSCANE2
  wire bscan_tms;
  wire bscan_reset;

  // Auxiliary BSCANE2 status signals
  wire bscan_capture;
  wire bscan_drck;
  wire bscan_runtest;
  wire bscan_sel;
  wire bscan_shift;
  wire bscan_update;
    
  // ----------------------------------------------------------------
  // 2. Xilinx 7-Series BSCANE2 Primitive Instance
  // ----------------------------------------------------------------
  BSCANE2 #(
      .JTAG_CHAIN(4)   // Maps to the standard Xilinx 'USER4' instruction register
  ) u_bscan_tunnel (
      .TCK     (bscan_tck),     // Out to SoC
      .TMS     (bscan_tms),     // Out to SoC
      .TDI     (bscan_tdi),     // Out to SoC
      .TDO     (bscan_tdo),     // IN from SoC internal logic
      
      .SEL     (bscan_sel),     
      .SHIFT   (bscan_shift),   
      .UPDATE  (bscan_update),  
      .CAPTURE (bscan_capture), 
      .RESET   (bscan_reset),   
      .RUNTEST (bscan_runtest), 
      .DRCK    (bscan_drck)     
  );

  Didactic didactic (
    .clk_in(clk_in),
    .gpio(gpio),
    .jtag_tck(bscan_tck),
    .jtag_tdi(bscan_tdi),
    .jtag_tdo(bscan_tdo),
    .jtag_tms(bscan_tms),
    .jtag_trst(~bscan_reset), // jtag_trst is active-low, and bscan_reset is active high
    .reset(reset),
    .spi_csn(spi_csn),
    .spi_data(spi_data),
    .spi_sck(spi_sck),
    .uart_rx(uart_rx),
    .uart_tx(uart_tx)
  );

endmodule

module Pll (
  output        clk_out,
  input         clk_in
 );

  wire clk_in_Pll;

  IBUF clkin1_ibufg
   (.O (clk_in_Pll),
    .I (clk_in));

  wire        clk_out_Pll;

  wire [15:0] do_unused;
  wire        drdy_unused;
  wire        psdone_unused;
  wire        locked_int;
  wire        clkfbout_Pll;
  wire        clkfbout_buf_Pll;
  wire        clkfboutb_unused;
  wire        clkout1_unused;
  wire        clkout2_unused;
  wire        clkout3_unused;
  wire        clkout4_unused;
  wire        clkout5_unused;
  wire        clkout6_unused;
  wire        clkfbstopped_unused;
  wire        clkinstopped_unused;

  PLLE2_ADV
  #(.BANDWIDTH            ("OPTIMIZED"),
    .COMPENSATION         ("ZHOLD"),
    .STARTUP_WAIT         ("FALSE"),
    .DIVCLK_DIVIDE        (2),
    .CLKFBOUT_MULT        (33),
    .CLKFBOUT_PHASE       (0.000),
    .CLKOUT0_DIVIDE       (33),
    .CLKOUT0_PHASE        (0.000),
    .CLKOUT0_DUTY_CYCLE   (0.500),
    .CLKIN1_PERIOD        (20.000))
  plle2_adv_inst
    // Output clocks
   (
    .CLKFBOUT            (clkfbout_Pll),
    .CLKOUT0             (clk_out_Pll),
    .CLKOUT1             (clkout1_unused),
    .CLKOUT2             (clkout2_unused),
    .CLKOUT3             (clkout3_unused),
    .CLKOUT4             (clkout4_unused),
    .CLKOUT5             (clkout5_unused),
     // Input clock control
    .CLKFBIN             (clkfbout_buf_Pll),
    .CLKIN1              (clk_in_Pll),
    .CLKIN2              (1'b0),
     // Tied to always select the primary input clock
    .CLKINSEL            (1'b1),
    // Ports for dynamic reconfiguration
    .DADDR               (7'h0),
    .DCLK                (1'b0),
    .DEN                 (1'b0),
    .DI                  (16'h0),
    .DO                  (do_unused),
    .DRDY                (drdy_unused),
    .DWE                 (1'b0),
    // Other control and status signals
    .LOCKED              (locked_int),
    .PWRDWN              (1'b0),
    .RST                 (1'b0));

  BUFG clkf_buf
   (.O (clkfbout_buf_Pll),
    .I (clkfbout_Pll));
  BUFG clkout1_buf
   (.O   (clk_out),
    .I   (clk_out_Pll));

endmodule
