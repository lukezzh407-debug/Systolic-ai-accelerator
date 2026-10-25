`ifndef TB_PARAMS_SVH
`define TB_PARAMS_SVH

// Match the original group-4 UVM / C software configuration.
// Override from the Makefile: +define+MATRIX_SIZE=32 +define+ARRAY_SIZE=8
`ifndef MATRIX_SIZE
  `define MATRIX_SIZE 8
`endif

`ifndef ARRAY_SIZE
  `define ARRAY_SIZE 8
`endif

`ifndef MATRIX_DW
  `define MATRIX_DW 32
`endif

`ifndef SUM_DW
  `define SUM_DW 32
`endif

`ifndef APB_AW
  `define APB_AW 16
`endif

`ifndef APB_DW
  `define APB_DW 32
`endif

`ifndef MAC_LATENCY
  `define MAC_LATENCY 16
`endif

`ifndef RAM_RD_LAT
  `define RAM_RD_LAT 1
`endif

// Register map seen by both the RTL APB slave and later C MMIO code.
// On Didactic-SoC these are offsets from 0x0151_0000; here PADDR is already stripped.
`define ACT_MATRIX_REG  16'h0000
`define WEI_MATRIX_REG  16'h0004
`define OUT_MATRIX_REG  16'h0008
`define CTRL_STS_REG    16'h000C
`define BIAS_REG        16'h0010

`define CTRL_START_BIT  0
`define CTRL_IN_DW_LSB  1
`define CTRL_OUT_DW_LSB 3
`define CTRL_ASIZE_LSB  5
`define CTRL_DONE_BIT   11

`endif
