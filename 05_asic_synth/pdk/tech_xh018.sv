module tech_not(
    input  logic a,
    output logic z
  );
   INHDX1 i_INHDX1(
    .A(a),
    .Q(z)
   );
endmodule

module tc_clk_inverter (
    input  logic clk_i,
    output logic clk_o
  );
   INHDX4 i_INHDX4(
    .A(clk_i),
    .Q(clk_o)
   );
endmodule

module tech_cg(
    input  logic clk,
    input  logic en,
    output logic clk_out
  );
   AND2HDX4 i_AND2HDX4(
    .A(clk),
    .B(en),
    .Q(clk_out)
   );
endmodule

module tc_clk_gating(
    input  logic clk_i,
    input  logic en_i,
    input  logic test_en_i,
    output logic clk_o
  );
   tech_cg i_tech_cg(
    .clk(clk_i),
    .en(en_i),
    .clk_out(clk_o)
   );
endmodule

module tc_clk_mux2 (
    input  logic clk0_i,
    input  logic clk1_i,
    input  logic clk_sel_i,
    output logic clk_o
  );
   MU2HDX4 i_MU2HDX4(
     .Q(clk_o),
     .IN0(clk0_i),
     .IN1(clk1_i),
     .S(clk_sel_i)
  );
endmodule

module prim_clock_gating (
  input  clk_i,
  input  en_i,
  input  test_en_i,
  output clk_o
  );
  tech_cg i_tech_cg (
    .clk(clk_i),
    .en(en_i),
    .clk_out(clk_o)
  );
endmodule

module tech_sync #(
    parameter SYNC_DEPTH = 2
  )(
    input  logic clk,
    input  logic rst_n,
    input  logic signal_i,
    output logic signal_sync_o
  );
  
  logic [SYNC_DEPTH:0] sync_internal;
  
  assign sync_internal[0] = signal_i;
  assign signal_sync_o = sync_internal[SYNC_DEPTH];

  for(genvar i=1; i<=SYNC_DEPTH; i++) begin
    DFFRQHDX1 i_DFFRQHDX1(
     .Q(sync_internal[i]),
     .CN(clk),
     .D(sync_internal[i-1]),
     .RN(rst_n)
    );
  end

endmodule
