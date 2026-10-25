class apb_seq_item extends uvm_sequence_item;
  typedef enum {READ, WRITE} dir_e;

  rand logic [`APB_AW-1:0] addr;
  rand logic [`APB_DW-1:0] data;
  rand dir_e               dir;
  logic                    slverr;

  constraint c_align { addr[1:0] == 2'b00; }

  `uvm_object_utils_begin(apb_seq_item)
    `uvm_field_int(addr, UVM_ALL_ON)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_enum(dir_e, dir, UVM_ALL_ON)
  `uvm_object_utils_end

  function new(string name = "apb_seq_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("%s addr=0x%0h data=0x%0h",
                     (dir == WRITE) ? "WR" : "RD", addr, data);
  endfunction
endclass
