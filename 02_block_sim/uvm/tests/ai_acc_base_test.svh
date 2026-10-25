class ai_acc_base_test extends uvm_test;
  `uvm_component_utils(ai_acc_base_test)

  ai_acc_env env;
  uvm_report_server rs;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = ai_acc_env::type_id::create("env", this);
    rs  = uvm_report_server::get_server();
    rs.set_max_quit_count(`MAX_QUIT_COUNT);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    uvm_top.print_topology();
  endfunction

  task apb_write(logic [`APB_AW-1:0] addr, logic [`APB_DW-1:0] data);
    apb_seq seq;
    seq = apb_seq::type_id::create("wr");
    seq.addr = addr;
    seq.data = data;
    seq.dir  = apb_seq_item::WRITE;
    seq.start(env.apb.sqr);
  endtask

  task apb_read(logic [`APB_AW-1:0] addr, output logic [`APB_DW-1:0] data);
    apb_seq seq;
    seq = apb_seq::type_id::create("rd");
    seq.addr = addr;
    seq.dir  = apb_seq_item::READ;
    seq.start(env.apb.sqr);
    data = seq.rdata;
  endtask

  task apply_reset();
    virtual apb_if vif;
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", vif))
      `uvm_fatal("RST", "apb_vif not set")
    vif.PRESET_N = 1'b0;
    repeat (8) @(posedge vif.PCLK);
    vif.PRESET_N = 1'b1;
    repeat (4) @(posedge vif.PCLK);
  endtask

  task config_dut(e_data_width in_dw, e_data_width out_dw);
    logic [31:0] wdata, rdata;
    wdata = make_ctrl(`ARRAY_SIZE, in_dw, out_dw, 1'b0, 1'b0);
    apb_write(`CTRL_STS_REG, wdata);
    apb_read (`CTRL_STS_REG, rdata);
    if (rdata[10:1] !== wdata[10:1])
      `uvm_error("CFG", $sformatf("CTRL mismatch w=0x%0h r=0x%0h", wdata, rdata))
  endtask

  task write_matrix(logic [`APB_AW-1:0] addr, e_data_width dw, logic signed [31:0] mat[]);
    int step;
    step = elems_per_word(dw);
    for (int i = 0; i < `MATRIX_SIZE * `MATRIX_SIZE; i += step)
      apb_write(addr, pack_word(dw, mat, i));
  endtask

  task write_bias(logic signed [31:0] bias[]);
    for (int i = 0; i < `MATRIX_SIZE; i++)
      apb_write(`BIAS_REG, bias[i]);
  endtask

  task start_and_wait();
    logic [31:0] data;
    int timeout;
    apb_read(`CTRL_STS_REG, data);
    data[0] = 1'b1;
    apb_write(`CTRL_STS_REG, data);
    timeout = 0;
    do begin
      apb_read(`CTRL_STS_REG, data);
      timeout++;
      if (timeout > 1_000_000)
        `uvm_fatal("RUN", "timeout waiting for DONE")
    end while (data[11] !== 1'b1);
    data[11] = 1'b1;
    data[0]  = 1'b0;
    apb_write(`CTRL_STS_REG, data);
  endtask

  task run_one_gemm(string name, e_data_width act_dw, e_data_width wei_dw,
                    e_data_width out_dw, string act_pat, string wei_pat);
    logic signed [31:0] act[];
    logic signed [31:0] wei[];
    logic signed [31:0] bias[];
    logic signed [31:0] got[];
    logic signed [31:0] exp[];
    int n, asz, tiles, out_i, out_j;
    logic [31:0] rdata;

    n   = `MATRIX_SIZE;
    asz = `ARRAY_SIZE;
    `uvm_info("GEMM", $sformatf("==== %s act=%0d wei=%0d out=%0d ====",
              name, act_dw, wei_dw, out_dw), UVM_LOW)

    act  = new[n*n];
    wei  = new[n*n];
    bias = new[n];
    got  = new[n*n];
    fill_pattern(act_pat, n, precision_bits(act_dw), act);
    fill_pattern(wei_pat, n, precision_bits(wei_dw), wei);
    for (int i = 0; i < n; i++) bias[i] = 0;

    apply_reset();
    config_dut(act_dw, out_dw);
    write_matrix(`ACT_MATRIX_REG, act_dw, act);
    config_dut(wei_dw, out_dw);
    write_matrix(`WEI_MATRIX_REG, wei_dw, wei);
    write_bias(bias);

    tiles = n / asz;
    out_i = 0;
    out_j = 0;
    for (int tr = 0; tr < tiles; tr++) begin
      for (int tc = 0; tc < tiles; tc++) begin
        start_and_wait();
        for (int r = 0; r < asz; r++)
          for (int c = 0; c < asz; c++) begin
            apb_read(`OUT_MATRIX_REG, rdata);
            got[(out_i+r)*n + (out_j+c)] = rdata;
          end
        out_j = (out_j + asz) % n;
      end
      out_i += asz;
    end

    golden_gemm(n, act, wei, bias, exp);
    for (int i = 0; i < n*n; i++)
      if (got[i] !== exp[i])
        `uvm_error("COMP", $sformatf("%s C[%0d]=%0d expected=%0d", name, i, got[i], exp[i]))
      else
        `uvm_info("COMP", $sformatf("%s C[%0d] ok", name, i), UVM_HIGH)
    `uvm_info("GEMM", $sformatf("%s compare done", name), UVM_LOW)
  endtask

  function void report_phase(uvm_phase phase);
    int nerr;
    nerr = rs.get_severity_count(UVM_ERROR);
    if (nerr == 0)
      `uvm_info(get_name(), "\n-------- UVM TEST PASS --------\n", UVM_LOW)
    else
      `uvm_info(get_name(), "\n-------- UVM TEST FAIL --------\n", UVM_LOW)
  endfunction
endclass
