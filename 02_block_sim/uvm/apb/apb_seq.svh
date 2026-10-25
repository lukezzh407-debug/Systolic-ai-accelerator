class apb_seq extends uvm_sequence #(apb_seq_item);
  `uvm_object_utils(apb_seq)

  logic [`APB_AW-1:0] addr;
  logic [`APB_DW-1:0] data;
  logic [`APB_DW-1:0] rdata;
  apb_seq_item::dir_e dir;

  function new(string name = "apb_seq");
    super.new(name);
  endfunction

  task body();
    apb_seq_item tr;
    tr = apb_seq_item::type_id::create("tr");
    start_item(tr);
    tr.addr = addr;
    tr.data = data;
    tr.dir  = dir;
    finish_item(tr);
    // Driver writes read data back into the same item object.
    rdata = tr.data;
  endtask
endclass
