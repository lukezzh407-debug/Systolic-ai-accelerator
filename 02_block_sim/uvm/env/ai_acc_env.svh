class ai_acc_env extends uvm_env;
  `uvm_component_utils(ai_acc_env)

  apb_agent apb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    apb = apb_agent::type_id::create("apb", this);
  endfunction
endclass
