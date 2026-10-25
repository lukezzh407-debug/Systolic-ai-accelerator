class ai_acc_reg_test extends ai_acc_base_test;
  `uvm_component_utils(ai_acc_reg_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    logic [31:0] rdata;
    logic [31:0] wdata;
    phase.raise_objection(this);
    apply_reset();

    wdata = make_ctrl(`ARRAY_SIZE, MODE_8BIT, MODE_32BIT, 1'b0, 1'b0);
    apb_write(`CTRL_STS_REG, wdata);
    apb_read (`CTRL_STS_REG, rdata);
    if (rdata[10:1] !== wdata[10:1])
      `uvm_error("REG", $sformatf("CTRL rw mismatch w=0x%0h r=0x%0h", wdata, rdata))
    else
      `uvm_info("REG", "CTRL readback OK", UVM_LOW)

    apb_write(`BIAS_REG, 32'h0000_0007);
    // bias is write-only FIFO-like in RTL; just prove the write does not error

    phase.drop_objection(this);
  endtask
endclass
