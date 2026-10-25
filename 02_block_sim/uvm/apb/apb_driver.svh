class apb_driver extends uvm_driver #(apb_seq_item);
  `uvm_component_utils(apb_driver)

  virtual apb_if vif;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual apb_if)::get(this, "", "apb_vif", vif))
      `uvm_fatal("DRV", "apb_vif not set")
  endfunction

  task run_phase(uvm_phase phase);
    apb_seq_item tr;
    vif.PSEL    <= 1'b0;
    vif.PENABLE <= 1'b0;
    vif.PWRITE  <= 1'b0;
    vif.PSTRB   <= '1;
    wait (vif.PRESET_N === 1'b1);

    forever begin
      seq_item_port.get_next_item(tr);

      @(posedge vif.PCLK);
      vif.PSEL    <= 1'b1;
      vif.PENABLE <= 1'b0;
      vif.PWRITE  <= (tr.dir == apb_seq_item::WRITE);
      vif.PADDR   <= tr.addr;
      vif.PWDATA  <= tr.data;
      vif.PSTRB   <= '1;

      @(posedge vif.PCLK);
      vif.PENABLE <= 1'b1;

      do @(posedge vif.PCLK); while (!vif.PREADY);

      tr.slverr = vif.PSLVERR;
      if (tr.dir == apb_seq_item::READ)
        tr.data = vif.PRDATA;

      if (tr.slverr)
        `uvm_error("DRV", $sformatf("PSLVERR %s", tr.convert2string()))

      vif.PSEL    <= 1'b0;
      vif.PENABLE <= 1'b0;

      `uvm_info("APB", tr.convert2string(), UVM_HIGH)
      seq_item_port.item_done();
    end
  endtask
endclass
