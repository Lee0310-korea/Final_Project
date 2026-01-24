`timescale 1ns / 1ps


module raddr_mux (
    input  logic [$clog2(320*240) - 1:0] debug_addr,
    input  logic [$clog2(320*240) - 1:0] analyze_addr,
    input  logic                         sel,
    output logic [$clog2(320*240) - 1:0] out_addr
);

    assign out_addr = (sel) ? analyze_addr : debug_addr;

endmodule
