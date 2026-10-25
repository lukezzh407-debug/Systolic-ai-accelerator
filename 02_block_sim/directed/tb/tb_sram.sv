`timescale 1ns/1ps

// Directed TB for rtl/sram.sv (simple_dualport_ram).
// Current RTL uses active-high sel / rden / wren. The old UVM TB used
// inverted *_n pins and did not check read data; this one does.
module tb_sram;

  localparam ADDR_WIDTH = 4;
  localparam DATA_WIDTH = 8;
  localparam DEPTH      = 1 << ADDR_WIDTH;

  logic                  clk;
  logic                  rst_n;
  logic                  sel;
  logic [ADDR_WIDTH-1:0] rd_addr;
  logic                  rden;
  logic [DATA_WIDTH-1:0] rd_data;
  logic [ADDR_WIDTH-1:0] wr_addr;
  logic                  wren;
  logic [DATA_WIDTH-1:0] wr_data;

  logic [DATA_WIDTH-1:0] shadow [0:DEPTH-1];
  int unsigned error_count = 0;

  simple_dualport_ram #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
  ) dut (
      .clk    (clk),
      .rst_n  (rst_n),
      .sel    (sel),
      .rd_addr(rd_addr),
      .rden   (rden),
      .rd_data(rd_data),
      .wr_addr(wr_addr),
      .wren   (wren),
      .wr_data(wr_data)
  );

  initial clk = 1'b0;
  always #5 clk = ~clk;

  initial begin
    if ($test$plusargs("DUMP_FSDB")) begin
      $fsdbDumpfile("wave/tb_sram.fsdb");
      $fsdbDumpvars(0, tb_sram);
      $fsdbDumpMDA(0, tb_sram);
    end
  end

  task automatic write_ram(input logic [ADDR_WIDTH-1:0] addr, input logic [DATA_WIDTH-1:0] data);
    @(posedge clk);
    wren    <= 1'b1;
    wr_addr <= addr;
    wr_data <= data;
    shadow[addr] = data;
    @(posedge clk);
    wren    <= 1'b0;
  endtask

  task automatic read_ram(input logic [ADDR_WIDTH-1:0] addr);
    @(posedge clk);
    rden    <= 1'b1;
    rd_addr <= addr;
    @(posedge clk);
    rden    <= 1'b0;
    #1;
    if (rd_data !== shadow[addr]) begin
      error_count++;
      $error("[SRAM] mismatch addr=%0d expected=0x%0h got=0x%0h", addr, shadow[addr], rd_data);
    end else begin
      $display("[SRAM] PASS addr=%0d data=0x%0h", addr, rd_data);
    end
  endtask

  initial begin
    rst_n   = 1'b0;
    sel     = 1'b0;
    wren    = 1'b0;
    rden    = 1'b0;
    rd_addr = '0;
    wr_addr = '0;
    wr_data = '0;

    repeat (3) @(posedge clk);
    rst_n = 1'b1;
    sel   = 1'b1;

    $display("[SRAM] write phase");
    for (int i = 0; i < DEPTH; i++) begin
      write_ram(i[ADDR_WIDTH-1:0], 8'hA0 + i[7:0]);
    end

    $display("[SRAM] read-back phase");
    for (int i = 0; i < DEPTH; i++) begin
      read_ram(i[ADDR_WIDTH-1:0]);
    end

    sel = 1'b0;
    repeat (4) @(posedge clk);

    if (error_count == 0) begin
      $display("\n======== SRAM TEST PASS ========\n");
      $finish;
    end else begin
      $display("\n======== SRAM TEST FAIL  errors=%0d ========\n", error_count);
      $fatal(1);
    end
  end

endmodule
