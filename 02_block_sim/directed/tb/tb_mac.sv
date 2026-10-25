`timescale 1ns/1ps

// Directed TB for MAC. Matches current rtl/MAC.sv:
//   MULT_MODE=0 : iterative Radix-4 Booth (used by AI_ACC_TOP)
//   mode = 1/2/3 : 8 / 16 / 32-bit iteration count
module tb_mac;

  localparam MATRIX_DW = 32;
  localparam SUM_DW    = 32;
  localparam MULT_MODE = 0;

  logic clk_in;
  logic reset_int;
  logic signed [MATRIX_DW-1:0] left_din;
  logic signed [MATRIX_DW-1:0] top_din;
  logic signed [MATRIX_DW-1:0] right_dout;
  logic signed [MATRIX_DW-1:0] down_dout;
  logic signed [SUM_DW-1:0]    shift_in;
  logic signed [SUM_DW-1:0]    sum_out;
  logic                        enable;
  logic                        shift_en;
  logic [1:0]                  mode;

  int unsigned error_count = 0;

  MAC #(
      .MATRIX_DW(MATRIX_DW),
      .SUM_DW   (SUM_DW),
      .MULT_MODE(MULT_MODE)
  ) dut (
      .clk_in    (clk_in),
      .reset_int (reset_int),
      .left_din  (left_din),
      .top_din   (top_din),
      .right_dout(right_dout),
      .down_dout (down_dout),
      .shift_in  (shift_in),
      .sum_out   (sum_out),
      .enable    (enable),
      .shift_en  (shift_en),
      .mode      (mode)
  );

  initial clk_in = 1'b0;
  always #5 clk_in = ~clk_in;

  initial begin
    if ($test$plusargs("DUMP_FSDB")) begin
      $fsdbDumpfile("wave/tb_mac.fsdb");
      $fsdbDumpvars(0, tb_mac);
    end
  end

  function automatic int booth_latency(logic [1:0] mode_in);
    case (mode_in)
      2'd1:    return 4;
      2'd2:    return 8;
      default: return 16;
    endcase
  endfunction

  task automatic load_accumulator(input logic signed [SUM_DW-1:0] value);
    @(negedge clk_in);
    shift_in = value;
    shift_en = 1'b1;
    @(negedge clk_in);
    shift_en = 1'b0;
    shift_in = '0;
    @(posedge clk_in);
    #1;
  endtask

  task automatic check(input bit cond, input string msg);
    if (!cond) begin
      error_count++;
      $error("[MAC] FAIL: %s", msg);
    end else begin
      $display("[MAC] PASS: %s", msg);
    end
  endtask

  task automatic run_one_mac(
      input logic [1:0] test_mode,
      input logic signed [31:0] a,
      input logic signed [31:0] b,
      input string test_name
  );
    int latency;
    longint signed product_full;
    logic signed [SUM_DW-1:0] expected_sum;
    begin
      latency      = booth_latency(test_mode);
      product_full = a * b;
      expected_sum = sum_out + product_full[SUM_DW-1:0];

      mode     = test_mode;
      left_din = a;
      top_din  = b;

      @(negedge clk_in);
      enable = 1'b1;
      @(negedge clk_in);
      enable = 1'b0;

      repeat (latency) @(posedge clk_in);
      #1;

      check(sum_out === expected_sum,
            $sformatf("%s  mode=%0d a=%0d b=%0d expected=%0d got=%0d",
                      test_name, test_mode, a, b, expected_sum, sum_out));
      check(right_dout === a[MATRIX_DW-1:0],
            $sformatf("%s right_dout", test_name));
      check(down_dout === b[MATRIX_DW-1:0],
            $sformatf("%s down_dout", test_name));
    end
  endtask

  initial begin
    reset_int = 1'b0;
    enable    = 1'b0;
    shift_en  = 1'b0;
    shift_in  = '0;
    mode      = 2'd1;
    left_din  = '0;
    top_din   = '0;

    repeat (4) @(posedge clk_in);
    reset_int = 1'b1;
    repeat (2) @(posedge clk_in);

    load_accumulator('0);
    run_one_mac(2'd1,  32'sd3,    32'sd5,    "8-bit +*+");
    run_one_mac(2'd1, -32'sd3,    32'sd5,    "8-bit -*+");
    run_one_mac(2'd1,  32'sd7,   -32'sd4,    "8-bit +*-");
    run_one_mac(2'd1, -32'sd8,   -32'sd6,    "8-bit -*-");

    load_accumulator('0);
    run_one_mac(2'd2,  32'sd123,   32'sd45,   "16-bit +*+");
    run_one_mac(2'd2, -32'sd123,   32'sd45,   "16-bit -*+");
    run_one_mac(2'd2,  32'sd300,  -32'sd12,   "16-bit +*-");
    run_one_mac(2'd2, -32'sd256,  -32'sd128,  "16-bit -*-");

    load_accumulator('0);
    run_one_mac(2'd3,  32'sd1000,    32'sd2000,   "32-bit +*+");
    run_one_mac(2'd3, -32'sd1000,    32'sd2000,   "32-bit -*+");
    run_one_mac(2'd3,  32'sd123456, -32'sd789,    "32-bit +*-");
    run_one_mac(2'd3, -32'sd12345,  -32'sd6789,   "32-bit -*-");

    load_accumulator(32'sd1234);
    check(sum_out === 32'sd1234, "shift_en load accumulator");

    if (error_count == 0) begin
      $display("\n======== MAC TEST PASS ========\n");
      $finish;
    end else begin
      $display("\n======== MAC TEST FAIL  errors=%0d ========\n", error_count);
      $fatal(1);
    end
  end

endmodule
