`timescale 1ns/1ps
`include "tb_defines.svh"

import uvm_pkg::*;
import ai_acc_sw_model::*;
import ai_acc_tb_pkg::*;

module tb_top;

  logic clk_in;

  apb_if apb_if(clk_in);

  AI_ACC_TOP #(
      .APB_AW        (`APB_AW),
      .APB_DW        (`APB_DW),
      .MATRIX_SIZE   (`MATRIX_SIZE),
      .ARRAY_SIZE    (`ARRAY_SIZE),
      .MATRIX_DW     (`MATRIX_DW),
      .SUM_DW        (`SUM_DW),
      .MAC_LATENCY   (`MAC_LATENCY),
      .RAM_READ_DELAY(`RAM_RD_LAT),
      .MULT_MODE     (0)
  ) dut (
      .PADDR        (apb_if.PADDR),
      .PENABLE      (apb_if.PENABLE),
      .PSEL         (apb_if.PSEL),
      .PWDATA       (apb_if.PWDATA),
      .PWRITE       (apb_if.PWRITE),
      .PSTRB        (4'hF),
      .PRDATA       (apb_if.PRDATA),
      .PREADY       (apb_if.PREADY),
      .PSLVERR      (apb_if.PSLVERR),
      .clk_in       (clk_in),
      .irq          (),
      .reset_int    (apb_if.PRESET_N),
      .irq_en       (1'b0),
      .ss_ctrl      (8'h00),
      .pmod_gpi     ('0),
      .pmod_gpio_oe (),
      .pmod_gpo     ()
  );

  initial clk_in = 1'b0;
  always #5 clk_in = ~clk_in;

  initial begin
    uvm_config_db#(virtual apb_if)::set(null, "*", "apb_vif", apb_if);
`ifdef FSDB
    if ($test$plusargs("DUMP_FSDB")) begin
      $fsdbDumpfile("wave/tb_top.fsdb");
      $fsdbDumpvars(0, tb_top);
    end
`endif
    run_test();
  end

endmodule
