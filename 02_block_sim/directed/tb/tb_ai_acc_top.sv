`timescale 1ns/1ps
`include "tb_params.svh"

import ai_acc_sw_model::*;

// Directed (non-UVM) testbench for AI_ACC_TOP.
// The stimulus sequence is the same one the later C program will issue over MMIO:
//   config -> write A -> (reconfig if needed) -> write W -> write bias -> start -> poll DONE -> read C
module tb_ai_acc_top;

  localparam int N     = `MATRIX_SIZE;
  localparam int ASZ   = `ARRAY_SIZE;
  localparam int APB_W = `APB_AW;
  localparam int DAT_W = `APB_DW;

  logic                  clk_in;
  logic                  reset_int;
  logic [APB_W-1:0]      PADDR;
  logic                  PENABLE;
  logic                  PSEL;
  logic [DAT_W-1:0]      PWDATA;
  logic                  PWRITE;
  logic [DAT_W/8-1:0]    PSTRB;
  logic [DAT_W-1:0]      PRDATA;
  logic                  PREADY;
  logic                  PSLVERR;

  int unsigned error_count = 0;
  int unsigned test_count  = 0;

  AI_ACC_TOP #(
      .APB_AW        (APB_W),
      .APB_DW        (DAT_W),
      .MATRIX_SIZE   (N),
      .ARRAY_SIZE    (ASZ),
      .MATRIX_DW     (`MATRIX_DW),
      .SUM_DW        (`SUM_DW),
      .MAC_LATENCY   (`MAC_LATENCY),
      .RAM_READ_DELAY(`RAM_RD_LAT),
      .MULT_MODE     (0)
  ) dut (
      .PADDR      (PADDR),
      .PENABLE    (PENABLE),
      .PSEL       (PSEL),
      .PWDATA     (PWDATA),
      .PWRITE     (PWRITE),
      .PSTRB      (PSTRB),
      .PRDATA     (PRDATA),
      .PREADY     (PREADY),
      .PSLVERR    (PSLVERR),
      .clk_in     (clk_in),
      .irq        (),
      .reset_int  (reset_int),
      .irq_en     (1'b0),
      .ss_ctrl    (8'h00),
      .pmod_gpi   ('0),
      .pmod_gpio_oe(),
      .pmod_gpo   ()
  );

  initial clk_in = 1'b0;
  always #5 clk_in = ~clk_in;

  initial begin
    if ($test$plusargs("DUMP_FSDB")) begin
      $fsdbDumpfile("wave/tb_ai_acc_top.fsdb");
      $fsdbDumpvars(0, tb_ai_acc_top);
    end
  end

  task automatic apb_idle();
    PSEL    <= 1'b0;
    PENABLE <= 1'b0;
    PWRITE  <= 1'b0;
    PADDR   <= '0;
    PWDATA  <= '0;
    PSTRB   <= '1;
  endtask

  task automatic apb_write(input logic [APB_W-1:0] addr, input logic [DAT_W-1:0] data);
    @(posedge clk_in);
    PSEL    <= 1'b1;
    PENABLE <= 1'b0;
    PWRITE  <= 1'b1;
    PADDR   <= addr;
    PWDATA  <= data;
    PSTRB   <= '1;
    @(posedge clk_in);
    PENABLE <= 1'b1;
    do @(posedge clk_in); while (!PREADY); //如果没准备好则一直等
    if (PSLVERR) begin
      error_count++;
      $error("[APB] PSLVERR on write addr=0x%0h data=0x%0h", addr, data);
    end
    apb_idle();
  endtask

  task automatic apb_read(input logic [APB_W-1:0] addr, output logic [DAT_W-1:0] data);
    @(posedge clk_in);
    PSEL    <= 1'b1;
    PENABLE <= 1'b0;
    PWRITE  <= 1'b0;
    PADDR   <= addr;
    @(posedge clk_in);
    PENABLE <= 1'b1;
    do @(posedge clk_in); while (!PREADY);
    data = PRDATA;
    if (PSLVERR) begin
      error_count++;
      $error("[APB] PSLVERR on read addr=0x%0h", addr);
    end
    apb_idle();
  endtask

  task automatic apply_reset();
    reset_int = 1'b0;
    apb_idle();
    repeat (8) @(posedge clk_in);
    reset_int = 1'b1;
    repeat (4) @(posedge clk_in);
  endtask

  task automatic config_dut(input e_data_width in_dw, input e_data_width out_dw);
    logic [31:0] wdata, rdata;
    wdata = make_ctrl(ASZ, in_dw, out_dw, 1'b0, 1'b0);
    apb_write(`CTRL_STS_REG, wdata);
    apb_read (`CTRL_STS_REG, rdata);
    if (rdata[10:1] !== wdata[10:1]) begin
      error_count++;
      $error("[CFG] CTRL mismatch wrote=0x%0h read=0x%0h", wdata, rdata);
    end
  endtask

  task automatic write_matrix(
      input logic [APB_W-1:0] addr,
      input e_data_width dw,
      input logic signed [31:0] mat[]
  );
    int step;
    step = elems_per_word(dw);
    for (int i = 0; i < N * N; i += step) begin
      apb_write(addr, pack_word(dw, mat, i));
    end
  endtask

  task automatic write_bias(input logic signed [31:0] bias[]);
    for (int i = 0; i < N; i++) begin
      apb_write(`BIAS_REG, bias[i]);
    end
  endtask

  task automatic start_and_wait();
    logic [31:0] data;
    int timeout;
    apb_read(`CTRL_STS_REG, data);
    data[0] = 1'b1;
    apb_write(`CTRL_STS_REG, data);

    timeout = 0;
    do begin
      apb_read(`CTRL_STS_REG, data);
      timeout++;
      if (timeout > 1_000_000) begin
        error_count++;
        $error("[RUN] timeout waiting for DONE");
        return;
      end
    end while (data[11] !== 1'b1);

    data[11] = 1'b1; // RW1C
    data[0]  = 1'b0;
    apb_write(`CTRL_STS_REG, data);
  endtask

  task automatic read_output(output logic signed [31:0] out_mat[]);
    logic [31:0] data;
    out_mat = new[N*N];
    for (int i = 0; i < N * N; i++) begin
      apb_read(`OUT_MATRIX_REG, data);
      out_mat[i] = data;
    end
  endtask

  task automatic compare_mats(
      input string name,
      input logic signed [31:0] got[],
      input logic signed [31:0] exp[]
  );
    int local_err;
    local_err = 0;
    for (int i = 0; i < N * N; i++) begin
      if (got[i] !== exp[i]) begin
        local_err++;
        error_count++;
        if (local_err <= 8) begin
          $error("[%s] C[%0d]=%0d expected=%0d", name, i, got[i], exp[i]);
        end
      end
    end
    if (local_err == 0) begin
      $display("[%s] PASS  %0d x %0d", name, N, N);
    end else begin
      $error("[%s] FAIL  %0d mismatches", name, local_err);
    end
  endtask

  // Same tiling loop as origin_project ai_acc_base_test::mat_mult_til_sram_test
  // and as the later C driver: one full SRAM load, then ARRAY_SIZE tiles.
  task automatic run_one_gemm(
      input string case_name,
      input e_data_width act_dw,
      input e_data_width wei_dw,
      input e_data_width out_dw,
      input string act_pat,
      input string wei_pat
  );
    logic signed [31:0] act[];
    logic signed [31:0] wei[];
    logic signed [31:0] bias[];
    logic signed [31:0] got[];
    logic signed [31:0] exp[];
    int tiles;
    int out_i, out_j;

    test_count++;
    $display("\n==== %s  act=%0d wei=%0d out=%0d pattern=%s/%s ====",
             case_name, act_dw, wei_dw, out_dw, act_pat, wei_pat);

    act  = new[N*N];
    wei  = new[N*N];
    bias = new[N];
    got  = new[N*N];

    fill_pattern(act_pat, N, precision_bits(act_dw), act);
    fill_pattern(wei_pat, N, precision_bits(wei_dw), wei);
    for (int i = 0; i < N; i++) bias[i] = 0; // C software currently also uses 0 in several modes

    apply_reset();

    config_dut(act_dw, out_dw);
    write_matrix(`ACT_MATRIX_REG, act_dw, act);

    config_dut(wei_dw, out_dw);
    write_matrix(`WEI_MATRIX_REG, wei_dw, wei);

    write_bias(bias);

    tiles = N / ASZ;
    out_i = 0;
    out_j = 0;
    for (int tr = 0; tr < tiles; tr++) begin
      for (int tc = 0; tc < tiles; tc++) begin
        $display("  tile (%0d,%0d)", tr, tc);
        start_and_wait();
        for (int r = 0; r < ASZ; r++) begin
          for (int c = 0; c < ASZ; c++) begin
            logic [31:0] data;
            apb_read(`OUT_MATRIX_REG, data);
            got[(out_i+r)*N + (out_j+c)] = data;
          end
        end
        out_j = (out_j + ASZ) % N;
      end
      out_i += ASZ;
    end

    golden_gemm(N, act, wei, bias, exp);
    compare_mats(case_name, got, exp);
  endtask

  initial begin
    string plus_mode;
    int    mode_sel;
    int    seed;

    if (!$value$plusargs("SEED=%d", seed)) seed = 1;
    void'($urandom(seed));
    $display("[TB] MATRIX_SIZE=%0d ARRAY_SIZE=%0d SEED=%0d", N, ASZ, seed);

    if ($value$plusargs("MODE=%s", plus_mode)) begin
      // Single mode, e.g. +MODE=2  or +MODE=identity
      if (plus_mode == "identity") begin
        run_one_gemm("identity_8b", MODE_8BIT, MODE_8BIT, MODE_32BIT, "identity", "identity");
      end else if (plus_mode == "ones") begin
        run_one_gemm("ones_8b", MODE_8BIT, MODE_4BIT, MODE_32BIT, "ones", "ones");
      end else if (plus_mode == "all") begin
        for (int i = 0; i < num_c_modes(); i++) begin
          test_mode_t m;
          m = c_mode(i);
          run_one_gemm(m.name, m.act_dw, m.wei_dw, m.out_dw, "random", "random");
        end
      end else begin
        mode_sel = plus_mode.atoi();
        begin
          test_mode_t m;
          m = c_mode(mode_sel);
          run_one_gemm(m.name, m.act_dw, m.wei_dw, m.out_dw, "random", "random");
        end
      end
    end else begin
      // Default smoke: identity + ones + one random 8b/4b case (C TEST_MODE_62 analogue)
      run_one_gemm("identity_8b", MODE_8BIT, MODE_8BIT, MODE_32BIT, "identity", "identity");
      run_one_gemm("ones_8b4b",   MODE_8BIT, MODE_4BIT, MODE_32BIT, "ones", "ones");
      run_one_gemm("rand_8b4b",   MODE_8BIT, MODE_4BIT, MODE_32BIT, "random", "random");
    end

    $display("\n======== AI_ACC_TOP  tests=%0d  errors=%0d ========", test_count, error_count);
    if (error_count == 0) begin
      $display("======== PASS ========\n");
      $finish;
    end else begin
      $display("======== FAIL ========\n");
      $fatal(1);
    end
  end

endmodule
