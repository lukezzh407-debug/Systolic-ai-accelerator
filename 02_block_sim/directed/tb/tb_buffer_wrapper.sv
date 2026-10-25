`timescale 1ns/1ps

// Directed TB for BUFFER_WRAPPER_SR (+ DATA_UNPACKER + SRAM banks).
// Ported from origin_project/group4/rtl/wrappers_sram/tb_BUFFER_WRAPPER_SR.sv
// without UVM. Default 8x8 (one tile) for a short review run; override:
//   make TEST=buffer SRAM_DEPTH=32 ARRAY_SIZE=8
module tb_buffer_wrapper;

`ifndef SRAM_DEPTH
  `define SRAM_DEPTH 8
`endif
`ifndef ARRAY_SIZE
  `define ARRAY_SIZE 8
`endif

  localparam int SRAM_DEPTH = `SRAM_DEPTH;
  localparam int ARRAY_SIZE = `ARRAY_SIZE;
  localparam int MATRIX_DW  = 32;
  localparam int SUM_DW     = 32;
  localparam int APB_AW     = 16;
  localparam int APB_DW     = 32;
  localparam int TOTAL_ELEMENTS = SRAM_DEPTH * SRAM_DEPTH;
  localparam int TILES_PER_DIM  = SRAM_DEPTH / ARRAY_SIZE;
  localparam int TOTAL_TILES    = TILES_PER_DIM * TILES_PER_DIM;
  localparam int TILE_ELEMS     = ARRAY_SIZE * ARRAY_SIZE;

  logic        pclk;
  logic        prst_n;
  logic        psel, penable, pwrite;
  logic [APB_AW-1:0] paddr;
  logic [APB_DW-1:0] pwr_data;
  logic        pready, pslverr;
  logic [APB_DW-1:0] prd_data;
  logic [ARRAY_SIZE-1:0] ctrl_act_fifoen, ctrl_wei_fifoen;
  logic [ARRAY_SIZE*MATRIX_DW-1:0] matrix_act_din, matrix_wei_din;
  logic [SUM_DW-1:0] matrix_c_dout;
  logic              matrix_c_valid;
  logic              sa_out_rd_en;
  logic              compute_en;
  logic [5:0]        array_size;
  logic [1:0]        matrix_dw, sum_dw;

  int unsigned error_count;
  int unsigned sa_read_count;
  logic signed [31:0] expected_matrix_c [0:1023];
  logic signed [31:0] expected_bias [0:31];
  logic               sa_done = 1'b0;

  function automatic int get_global_index(int seq_idx);
    int tile_idx, tile_row, tile_col;
    int local_idx, local_r, local_c;
    tile_idx  = seq_idx / TILE_ELEMS;
    tile_row  = tile_idx / TILES_PER_DIM;
    tile_col  = tile_idx % TILES_PER_DIM;
    local_idx = seq_idx % TILE_ELEMS;
    local_r   = local_idx / ARRAY_SIZE;
    local_c   = local_idx % ARRAY_SIZE;
    return (tile_row * ARRAY_SIZE + local_r) * SRAM_DEPTH
         + (tile_col * ARRAY_SIZE + local_c);
  endfunction

  always_ff @(posedge pclk or negedge prst_n) begin
    if (!prst_n)
      sa_read_count <= 0;
    else if (sa_out_rd_en)
      sa_read_count <= sa_read_count + 1;
  end

  assign matrix_c_dout  = expected_matrix_c[get_global_index(sa_read_count)];
  assign matrix_c_valid = 1'b1;

  BUFFER_WRAPPER_SR #(
      .SRAM_DEPTH(SRAM_DEPTH),
      .ARRAY_SIZE(ARRAY_SIZE),
      .MATRIX_DW (MATRIX_DW),
      .SUM_DW    (SUM_DW),
      .APB_AW    (APB_AW),
      .APB_DW    (APB_DW)
  ) dut (.*);

  initial pclk = 1'b0;
  always #5 pclk = ~pclk;

  initial begin
    if ($test$plusargs("DUMP_FSDB")) begin
      $fsdbDumpfile("wave/tb_buffer_wrapper.fsdb");
      $fsdbDumpvars(0, tb_buffer_wrapper);
    end
  end

  task automatic apb_idle();
    psel    <= 1'b0;
    penable <= 1'b0;
    pwrite  <= 1'b0;
  endtask

  task automatic apb_write(input logic [APB_AW-1:0] addr, input logic [APB_DW-1:0] data);
    @(posedge pclk);
    psel     <= 1'b1;
    penable  <= 1'b0;
    pwrite   <= 1'b1;
    paddr    <= addr;
    pwr_data <= data;
    @(posedge pclk);
    penable <= 1'b1;
    do @(posedge pclk); while (!pready);
    if (pslverr) begin
      error_count++;
      $error("[APB] PSLVERR write 0x%0h", addr);
    end
    apb_idle();
  endtask

  task automatic apb_read(input logic [APB_AW-1:0] addr, output logic [APB_DW-1:0] data);
    @(posedge pclk);
    psel    <= 1'b1;
    penable <= 1'b0;
    pwrite  <= 1'b0;
    paddr   <= addr;
    @(posedge pclk);
    penable <= 1'b1;
    do @(posedge pclk); while (!pready);
    data = prd_data;
    if (pslverr) begin
      error_count++;
      $error("[APB] PSLVERR read 0x%0h", addr);
    end
    apb_idle();
  endtask

  task automatic apply_reset();
    prst_n          = 1'b0;
    sa_done         = 1'b0;
    ctrl_act_fifoen = '0;
    ctrl_wei_fifoen = '0;
    apb_idle();
    paddr    = '0;
    pwr_data = '0;
    repeat (3) @(posedge pclk);
    prst_n = 1'b1;
    @(posedge pclk);
  endtask

  function automatic logic [31:0] base_cfg(input logic [1:0] in_dw);
    // [10:5]=array_size  [4:3]=out_dw=32b  [2:1]=in_dw
    return (ARRAY_SIZE[5:0] << 5) | (2'd3 << 3) | (in_dw << 1);
  endfunction

  task automatic test_data_width(input logic [1:0] mode, input string mode_name);
    int elems_per_word;
    int bitw;
    logic [31:0] mask;
    logic signed [31:0] expected_act [0:1023];
    logic signed [31:0] expected_wei [0:1023];
    int local_err;
    int val_act, val_wei;
    logic [31:0] word_act, word_wei;

    local_err = 0;

    case (mode)
      2'b00: begin elems_per_word = 8; bitw = 4;  mask = 32'h0000_000F; end
      2'b01: begin elems_per_word = 4; bitw = 8;  mask = 32'h0000_00FF; end
      2'b10: begin elems_per_word = 2; bitw = 16; mask = 32'h0000_FFFF; end
      default: begin elems_per_word = 1; bitw = 32; mask = 32'hFFFF_FFFF; end
    endcase

    $display("\n==== BUFFER write/read  %s (mode=%b)  %0dx%0d ====",
             mode_name, mode, SRAM_DEPTH, SRAM_DEPTH);

    apply_reset();
    apb_write(16'h000C, base_cfg(mode));

    for (int i = 0; i < TOTAL_ELEMENTS; i += elems_per_word) begin
      word_act = '0;
      word_wei = '0;
      for (int e = 0; e < elems_per_word; e++) begin
        unique case (mode)
          2'b00: begin val_act = ((i+e) % 16) - 8;           val_wei = 7 - ((i+e) % 16); end
          2'b01: begin val_act = ((i+e) % 256) - 128;        val_wei = 127 - ((i+e) % 256); end
          2'b10: begin val_act = ((i+e) % 65536) - 32768;    val_wei = 32767 - ((i+e) % 65536); end
          default: begin val_act = -(i+e) * 1000;            val_wei = (i+e) * 1000; end
        endcase
        expected_act[i+e] = val_act;
        expected_wei[i+e] = val_wei;
        word_act |= ((val_act & mask) << (e * bitw));
        word_wei |= ((val_wei & mask) << (e * bitw));
      end
      apb_write(16'h0000, word_act);
      apb_write(16'h0004, word_wei);
    end

    for (int tile = 0; tile < TOTAL_TILES; tile++) begin
      int tile_row = tile / TILES_PER_DIM;
      int tile_col = tile % TILES_PER_DIM;
      logic [31:0] dummy;

      apb_write(16'h000C, base_cfg(mode) | 32'h1);

      for (int d = 0; d < SRAM_DEPTH; d++) begin
        ctrl_act_fifoen = {ARRAY_SIZE{1'b1}};
        ctrl_wei_fifoen = {ARRAY_SIZE{1'b1}};
        @(posedge pclk);
        #1;
        for (int f = 0; f < ARRAY_SIZE; f++) begin
          logic signed [31:0] act_val = matrix_act_din[f*MATRIX_DW +: MATRIX_DW];
          logic signed [31:0] wei_val = matrix_wei_din[f*MATRIX_DW +: MATRIX_DW];
          int exp_act_idx = (tile_row * ARRAY_SIZE + f) * SRAM_DEPTH + d;
          int exp_wei_idx = (tile_col * ARRAY_SIZE + f) * SRAM_DEPTH + d;
          if (act_val !== expected_act[exp_act_idx]) begin
            local_err++;
            if (local_err <= 8)
              $error("ACT tile=%0d bank=%0d d=%0d exp=%0d got=%0d",
                     tile, f, d, expected_act[exp_act_idx], act_val);
          end
          if (wei_val !== expected_wei[exp_wei_idx]) begin
            local_err++;
            if (local_err <= 8)
              $error("WEI tile=%0d bank=%0d d=%0d exp=%0d got=%0d",
                     tile, f, d, expected_wei[exp_wei_idx], wei_val);
          end
        end
      end
      ctrl_act_fifoen = '0;
      ctrl_wei_fifoen = '0;
      @(posedge pclk);

      // Advance hardware tile_cnt by reading one tile of C.
      for (int r = 0; r < TILE_ELEMS; r++)
        apb_read(16'h0008, dummy);
    end

    error_count += local_err;
    if (local_err == 0)
      $display("[BUFFER] PASS unpack+tiling  %s", mode_name);
    else
      $error("[BUFFER] FAIL %s  %0d mismatches", mode_name, local_err);
  endtask

  task automatic test_bias_and_readout();
    int local_err;
    logic [31:0] read_data;
    int global_idx, global_col;
    logic signed [31:0] expected_final;

    local_err = 0;
    $display("\n==== BUFFER bias + APB readout ====");
    apply_reset();

    for (int i = 0; i < SRAM_DEPTH; i++) begin
      expected_bias[i] = -500 + i * 25;
      apb_write(16'h0010, expected_bias[i]);
    end
    for (int i = 0; i < TOTAL_ELEMENTS; i++)
      expected_matrix_c[i] = i * 10 - 5000;

    for (int tile = 0; tile < TOTAL_TILES; tile++) begin
      apb_write(16'h000C, base_cfg(2'b11) | 32'h1);
      for (int i = 0; i < TILE_ELEMS; i++) begin
        global_idx = get_global_index(tile * TILE_ELEMS + i);
        global_col = global_idx % SRAM_DEPTH;
        expected_final = expected_matrix_c[global_idx] + expected_bias[global_col];
        apb_read(16'h0008, read_data);
        if (read_data !== expected_final) begin
          local_err++;
          if (local_err <= 8)
            $error("C seq=%0d exp=%0d got=%0d", tile*TILE_ELEMS+i, expected_final, read_data);
        end
      end
    end

    error_count += local_err;
    if (local_err == 0)
      $display("[BUFFER] PASS bias mapping");
    else
      $error("[BUFFER] FAIL bias  %0d mismatches", local_err);
  endtask

  initial begin
    error_count = 0;
    for (int i = 0; i < 1024; i++) expected_matrix_c[i] = '0;
    for (int i = 0; i < 32; i++)   expected_bias[i] = '0;

    $display("BUFFER_WRAPPER_SR  SRAM_DEPTH=%0d  ARRAY_SIZE=%0d", SRAM_DEPTH, ARRAY_SIZE);

    test_data_width(2'b11, "32-bit");
    test_data_width(2'b10, "16-bit");
    test_data_width(2'b01, "8-bit");
    test_data_width(2'b00, "4-bit");
    test_bias_and_readout();

    if (error_count == 0) begin
      $display("\n======== BUFFER_WRAPPER TEST PASS ========\n");
      $finish;
    end else begin
      $display("\n======== BUFFER_WRAPPER TEST FAIL  errors=%0d ========\n", error_count);
      $fatal(1);
    end
  end

endmodule
