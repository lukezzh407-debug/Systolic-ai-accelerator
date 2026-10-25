`ifndef APB_IF_SV
`define APB_IF_SV

`include "tb_params.svh"

interface apb_if(input logic PCLK);
  logic PRESET_N = 1'b0;
  logic [`APB_AW-1:0] PADDR;
  logic [`APB_DW-1:0] PWDATA;
  logic [`APB_DW-1:0] PRDATA;
  logic               PSEL;
  logic               PENABLE;
  logic               PWRITE;
  logic               PREADY;
  logic               PSLVERR;
  logic [`APB_DW/8-1:0] PSTRB;

  clocking master_cb @(posedge PCLK);
    default input #1step output #1step;
    output PADDR, PSEL, PENABLE, PWRITE, PWDATA, PSTRB;
    input  PRDATA, PREADY, PSLVERR;
  endclocking

  modport master(input PRESET_N, clocking master_cb);
endinterface

`endif
