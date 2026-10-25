class ai_acc_smoke_test extends ai_acc_base_test;
  `uvm_component_utils(ai_acc_smoke_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    run_one_gemm("identity_8b", MODE_8BIT, MODE_8BIT, MODE_32BIT, "identity", "identity");
    run_one_gemm("ones_8b4b",   MODE_8BIT, MODE_4BIT, MODE_32BIT, "ones", "ones");
    phase.drop_objection(this);
  endtask
endclass
