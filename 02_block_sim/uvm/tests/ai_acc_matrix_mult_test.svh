// Walks the same 10 C TEST_MODE_* combinations as main_ai_acc_sram.c.
class ai_acc_matrix_mult_test extends ai_acc_base_test;
  `uvm_component_utils(ai_acc_matrix_mult_test)

  int mode_sel = -1;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    test_mode_t m;
    phase.raise_objection(this);

    if ($value$plusargs("MODE=%d", mode_sel)) begin
      m = c_mode(mode_sel);
      run_one_gemm(m.name, m.act_dw, m.wei_dw, m.out_dw, "random", "random");
    end else begin
      for (int i = 0; i < num_c_modes(); i++) begin
        m = c_mode(i);
        run_one_gemm(m.name, m.act_dw, m.wei_dw, m.out_dw, "random", "random");
      end
    end

    phase.drop_objection(this);
  endtask
endclass
