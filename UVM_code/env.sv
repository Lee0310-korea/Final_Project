class env extends uvm_env;
  `uvm_component_utils(env)

  agent a;
  scoreboard sb;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    a  = agent::type_id::create("a", this);
    sb = scoreboard::type_id::create("sb", this);
    `uvm_info("env", "Starting_build_phase", UVM_LOW)
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    a.mon.in_data_port.connect(sb.in_imp_port);
    a.mon.out_data_port.connect(sb.out_imp_port);
    `uvm_info("env", "Starting_connect_phase", UVM_LOW)
  endfunction
endclass