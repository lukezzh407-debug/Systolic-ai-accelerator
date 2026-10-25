`timescale 1ns/1ps

// Directed TB for SYSTOLIC_ARRAY_CONTROLLER.
// Stimulus follows origin_project/group4/rtl/tb_SYSTOLIC_ARRAY_CONTROLLER.sv.
// Added: timeout, SA_done pulse, MAC_en delayed vs act_fifoen by RAM_READ_DELAY.
module tb_controller;

  localparam int unsigned MAX_MATRIX_SIZE = 32;
  localparam int unsigned ARRAY_SIZE      = 8;
  localparam int unsigned M_DIM           = ARRAY_SIZE;
  localparam int unsigned K_DIM           = ARRAY_SIZE;
  localparam int unsigned N_DIM           = ARRAY_SIZE;
  localparam int unsigned MULT_MODE       = 0;
  localparam int unsigned RAM_READ_DELAY  = 1;
  localparam int unsigned DIAG_NUM        = 2 * ARRAY_SIZE - 1;

  logic clk;
  logic rst_n;
  logic EN;
  logic [1:0] mode;
  logic SA_computen;
  logic [M_DIM-1:0] act_fifoen;
  logic [N_DIM-1:0] weight_fifoen;
  logic [DIAG_NUM-1:0] MAC_en;
  logic SA_done;

  int unsigned cycle_count;
  int unsigned error_count;
  int unsigned delay_err;
  int unsigned done_seen;

  logic [M_DIM-1:0] act_fifoen_d;

  SYSTOLIC_ARRAY_CONTROLLER #(
      .MAX_MATRIX_SIZE(MAX_MATRIX_SIZE),
      .ARRAY_SIZE     (ARRAY_SIZE),
      .M_DIM          (M_DIM),
      .K_DIM          (K_DIM),
      .N_DIM          (N_DIM),
      .MULT_MODE      (MULT_MODE),
      .RAM_READ_DELAY (RAM_READ_DELAY)
  ) dut (
      .clk          (clk),
      .rst_n        (rst_n),
      .EN           (EN),
      .mode         (mode),
      .SA_computen  (SA_computen),
      .act_fifoen   (act_fifoen),
      .weight_fifoen(weight_fifoen),
      .MAC_en       (MAC_en),
      .SA_done      (SA_done)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  initial begin
    if ($test$plusargs("DUMP_FSDB")) begin
      $fsdbDumpfile("wave/tb_controller.fsdb");
      $fsdbDumpvars(0, tb_controller);
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_count  <= 0;
      act_fifoen_d <= '0;
    end else begin
      cycle_count  <= cycle_count + 1;
      act_fifoen_d <= act_fifoen;
    end
  end

  // Sample registered values at the clock edge: MAC_en is act_fifoen delayed 1 cycle.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      delay_err <= 0;
    end else if (cycle_count > 3) begin
      if (MAC_en[M_DIM-1:0] !== act_fifoen_d) begin
        delay_err <= delay_err + 1;
        $error("[%0t] MAC_en delay mismatch  MAC_en[ASZ-1:0]=%b  act_fifoen_d=%b",
               $time, MAC_en[M_DIM-1:0], act_fifoen_d);
      end
      if (act_fifoen !== weight_fifoen) begin
        delay_err <= delay_err + 1;
        $error("[%0t] act_fifoen != weight_fifoen  %b vs %b",
               $time, act_fifoen, weight_fifoen);
      end
    end
  end

  always @(posedge clk) begin
    if (rst_n) begin
      #1;
      $display("[%0t] cyc=%0d EN=%b computen=%b act=%b wei=%b MAC=%b done=%b",
               $time, cycle_count, EN, SA_computen,
               act_fifoen, weight_fifoen, MAC_en, SA_done);
    end
  end

  task automatic apply_reset;
    rst_n = 1'b0;
    EN    = 1'b0;
    mode  = 2'd3;
    repeat (5) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);
  endtask

  task automatic start_controller;
    @(negedge clk);
    EN = 1'b1;
    @(negedge clk);
    EN = 1'b0;
  endtask

  initial begin
    error_count = 0;
    done_seen   = 0;

    $display("============================================================");
    $display("SYSTOLIC_ARRAY_CONTROLLER  ARRAY_SIZE=%0d  MAX_MATRIX_SIZE=%0d",
             ARRAY_SIZE, MAX_MATRIX_SIZE);
    $display("MULT_MODE=%0d (0=Booth)  RAM_READ_DELAY=%0d  mode=32-bit",
             MULT_MODE, RAM_READ_DELAY);
    $display("============================================================");

    apply_reset();
    start_controller();

    fork
      begin
        wait (SA_done === 1'b1);
        done_seen = 1;
        $display("[%0t] SA_done seen at cycle %0d", $time, cycle_count);
        @(posedge clk);
        #1;
        if (SA_done !== 1'b0) begin
          error_count++;
          $error("SA_done should be a 1-cycle pulse (DONE state then IDLE)");
        end
      end
      begin
        repeat (20000) @(posedge clk);
        if (!done_seen) begin
          error_count++;
          $error("timeout waiting for SA_done");
        end
      end
    join_any
    disable fork;

    repeat (8) @(posedge clk);

    if (!done_seen)
      error_count++;

    error_count += delay_err;

    if (error_count == 0) begin
      $display("\n======== CONTROLLER TEST PASS ========\n");
      $finish;
    end else begin
      $display("\n======== CONTROLLER TEST FAIL  errors=%0d ========\n", error_count);
      $fatal(1);
    end
  end

endmodule
