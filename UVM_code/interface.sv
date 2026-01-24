interface dut_if (
    input bit clk,
    input bit reset
);
    // SCCB
    logic                   SDA;
    logic                   SCL;

    // OV7670
    logic                   xclk;
    logic                   cam_clk;
    logic                   href;
    logic                   vsync;
    logic [ 7:0]            data;

    // STM
    logic                   stm_trigger;

    // UART
    logic                   tx;
    logic                   rx;

    // Debug & Output Ports
    logic                   debug_h_sync;
    logic                   debug_v_sync;
    logic [ 3:0]            r_port;
    logic [ 3:0]            g_port;
    logic [ 3:0]            b_port;
    logic [$clog2(65)-1:0]  target_cnt;

    // Internal Signal Monitoring (via top.sv assignments)
    logic                   we;
    logic                   oe;
    logic [15:0]            wData;

endinterface