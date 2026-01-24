package tb_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"
	typedef logic [15:0] frame_t[240][320];
    `include "./testbench/transfer.sv"
    `include "./testbench/seq_item.sv"
    `include "./testbench/seq_lib.sv"
    `include "./testbench/sequencer.sv"
    `include "./testbench/monitor.sv"
    `include "./testbench/scoreboard.sv"
    `include "./testbench/driver.sv"
    `include "./testbench/agent.sv"
    `include "./testbench/env.sv"
    `include "./testbench/test.sv"
endpackage