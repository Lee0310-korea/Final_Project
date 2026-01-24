class agent extends uvm_agent;
  `uvm_component_utils(agent)

  uvm_sequencer #(drv_pkt_c) sqr;
  driver              drv;
  monitor                    mon;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    sqr = uvm_sequencer#(drv_pkt_c)::type_id::create("sqr", this);
    drv = driver::type_id::create("drv", this);
    mon = monitor::type_id::create("mon", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    drv.seq_item_port.connect(sqr.seq_item_export);
  endfunction
endclass