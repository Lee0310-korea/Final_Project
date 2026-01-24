`timescale 1ns / 1ps

module top_module (
    // global signal
    input  logic                    clk,
    input  logic                    reset,
    //SCCB
    output logic                    SDA,
    output logic                    SCL,
    //OV7670
    output logic                    xclk,
    input  logic                    cam_clk,
    input  logic                    href,
    input  logic                    vsync,
    input  logic [             7:0] data,
    //stm
    // input  logic                    btn_trigger,
    input  logic                    stm_trigger,
    //UART
    output logic                    tx,
    input  logic                    rx,
    //debug
    output logic                    debug_h_sync,
    output logic                    debug_v_sync,
    output logic [             3:0] r_port,
    output logic [             3:0] g_port,
    output logic [             3:0] b_port,
    output logic [$clog2(65) - 1:0] target_cnt
);

    localparam H_PIXELS = 320;
    localparam V_PIXELS = 240;
    localparam FRAME_SIZE = H_PIXELS * V_PIXELS;

    logic sys_clk;
    assign xclk = sys_clk;

    logic                              frame_done_toggle;
    logic                              we;
    logic [$clog2(FRAME_SIZE) - 1 : 0] wAddr;
    logic [                      15:0] wData;

    logic [                      15:0] rData;
    logic [$clog2(FRAME_SIZE) - 1 : 0] debug_addr;
    logic [                      15:0] debug_data;
    logic                              detect_pixel;

    logic [$clog2(FRAME_SIZE) - 1 : 0] out_addr;


    logic                              addr_sel;
    logic [$clog2(FRAME_SIZE) - 1 : 0] analyze_addr;
    logic [                       9:0] analyzer_x_label;
    logic [                       9:0] analyzer_y_label;
    logic                              analyzer_DE;
    logic                              analyzer_vsync;

    logic [                       9:0] object_x;
    logic [                       9:0] object_y;
    logic                              target_valid;

    logic                              tx_push;
    logic [                       7:0] tx_push_data;
    logic                              tx_fifo_full;

    logic                              debug_DE;
    logic [                       9:0] debug_x_pixel;
    logic [                       9:0] debug_y_pixel;

    SCCB_MASTER U_SCCB_MASTER (
        .clk  (clk),
        .reset(reset),
        .SCL  (SCL),
        .SDA  (SDA)
    );

    OV7670_Mem_Controller #(
        .H_PIXELS(H_PIXELS),
        .V_PIXELS(V_PIXELS)
    ) U_OV7670_MEM_CTRL (
        .clk              (cam_clk),
        .reset            (reset),
        .trigger          (stm_trigger),
        .href             (href),
        .vsync            (vsync),
        .data             (data),
        .we               (we),
        .wAddr            (wAddr),
        .wData            (wData),
        .frame_done_toggle(frame_done_toggle)
    );

    pixel_clk_gen U_SYSCLK_GEN (
        .clk  (clk),
        .reset(reset),
        .pclk (sys_clk)
    );
    frame_buffer U_FRAME_BUFFER (
        .wclk (cam_clk),
        .we   (we),
        .wAddr(wAddr),
        .wData(wData),
        .rclk (sys_clk),
        .oe   (1'b1),
        .rAddr(out_addr),
        .rData(rData)
    );

    analyzer_addr U_ANALYZER_ADDR (
        .clk              (sys_clk),
        .reset            (reset),
        .frame_done_toggle(frame_done_toggle),
        .analyze_addr     (analyze_addr),
        .addr_sel         (addr_sel),
        .x_label          (analyzer_x_label),
        .y_label          (analyzer_y_label),
        .DE               (analyzer_DE),
        .vsync            (analyzer_vsync)
    );

    raddr_mux U_RADDR_MUX (
        .debug_addr  (debug_addr),    //vga ?��면출?��
        .analyze_addr(analyze_addr),
        .sel         (addr_sel),
        .out_addr    (out_addr)
    );

    color_detect_filter U_COLOR_DETECT_FILTER (
        .rgb_data(rData),
        .filter_sel(2'b01),  // 00 : ?���? / 01 : R  / 10 : G / 11 : B, ?���? stm?��?�� 받아?��?��?���? ?��?��?���?
        .detect_pixel(detect_pixel),
        .debug_data(debug_data)
    );

    multi_object_detect #(
        .H_PIXELS(H_PIXELS),
        .MAX_OBJECTS(64)
    ) U_MULTI_OBJECT_DETECT (
        .clk         (sys_clk),
        .reset       (reset),
        .vsync       (analyzer_vsync),
        .x_pixel     (analyzer_x_label),
        .y_pixel     (analyzer_y_label),
        .DE          (analyzer_DE),
        .detect_pixel(detect_pixel),
        .object_x    (object_x),
        .object_y    (object_y),
        .target_valid(target_valid),
        .target_cnt  (target_cnt)         //debug?��
    );

     result_sender U_SENDER (
         .clk         (sys_clk),
         .reset       (reset),
         .object_x    (object_x),
         .object_y    (object_y),
         .target_valid(target_valid),
         .tx_push     (tx_push),
         .tx_push_data(tx_push_data),
         .tx_fifo_full(tx_fifo_full)
     );

     Uart #(
         .SYSCLK  (25_000_000),
         .BAUDRATE(115200)
     ) U_UART (
         .clk          (sys_clk),
         .rst          (reset),
         .tx           (tx),
         .rx           (rx),
         .tx_push      (tx_push),
         .tx_push_data (tx_push_data),
         .tx_fifo_full (tx_fifo_full),
         .rx_pop       (1'b0),
         .rx_pop_data  (),
         .rx_fifo_empty(),
         .tx_busy      ()
     );

    VGA_Syncher U_VGA_SYNCHER (
        .clk    (sys_clk),
        .reset  (reset),
        .h_sync (debug_h_sync),
        .v_sync (debug_v_sync),
        .DE     (debug_DE),
        .x_pixel(debug_x_pixel),
        .y_pixel(debug_y_pixel)
    );

    ImgMemReader_Debug U_IMG_DEBUG (
        .clk         (sys_clk),
        .reset       (reset),
        .DE          (debug_DE && !addr_sel),
        .x_pixel     (debug_x_pixel),
        .y_pixel     (debug_y_pixel),
        .addr        (debug_addr),
        .imgData     (debug_data),
        .object_x    (object_x),
        .object_y    (object_y),
        .target_valid(target_valid),
        .analysis_busy(addr_sel),
        .r_port      (r_port),
        .g_port      (g_port),
        .b_port      (b_port)
    );



endmodule
