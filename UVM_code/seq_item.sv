class seq_item_c extends uvm_sequence_item;
    bit                    cam_clk;
    bit                    href;
    bit                    vsync;
    bit [             7:0] data;
    bit                    stm_trigger;
    bit                    target_valid;
    bit [$clog2(65) - 1:0] target_cnt;
    bit [             3:0] r_port;
    bit [             3:0] g_port;
    bit [             3:0] b_port;
    bit                    rx;

    `uvm_object_utils_begin(seq_item_c)
        `uvm_field_int(cam_clk, UVM_DEFAULT)
        `uvm_field_int(href, UVM_DEFAULT)
        `uvm_field_int(vsync, UVM_DEFAULT)
        `uvm_field_int(data, UVM_DEFAULT)
        `uvm_field_int(stm_trigger, UVM_DEFAULT)
        `uvm_field_int(rx, UVM_DEFAULT)
        `uvm_field_int(r_port, UVM_DEFAULT)
        `uvm_field_int(g_port, UVM_DEFAULT)
        `uvm_field_int(b_port, UVM_DEFAULT)
        `uvm_field_int(target_valid, UVM_DEFAULT)
        `uvm_field_int(target_cnt, UVM_DEFAULT)
    `uvm_object_utils_end


    function new(string name = "seq_item_c");
        super.new(name);
    endfunction  //new()
endclass  //seq_item extends superClass
