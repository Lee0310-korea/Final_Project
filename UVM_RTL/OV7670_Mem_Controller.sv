`timescale 1ns / 1ps

module OV7670_Mem_Controller #(
    parameter H_PIXELS   = 320,                 //QQVGA      
    parameter V_PIXELS   = 240,                 //QQVGA      
    parameter FRAME_SIZE = H_PIXELS * V_PIXELS
) (
    input  logic                            clk,
    input  logic                            reset,
    // STM32 input
    input  logic                            trigger,
    // OV7670 side
    input  logic                            href,
    input  logic                            vsync,
    input  logic [                     7:0] data,
    // memory side
    output logic                            we,
    output logic [$clog2(FRAME_SIZE) - 1:0] wAddr,
    output logic [                    15:0] wData,
    // signal
    output logic                            frame_done_toggle
);

    logic        byte_sel;
    logic [15:0] pixelData;

    assign wData = pixelData;

    // trigger CDC & rising edge
    logic trig_d1, trig_d2, trig_d3;

    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            trig_d1 <= 0;
            trig_d2 <= 0;
            trig_d3 <= 0;
        end else begin
            trig_d1 <= trigger;
            trig_d2 <= trig_d1;
            trig_d3 <= trig_d2;
        end
    end

    wire  trig_rise = trig_d2 & ~trig_d3;
    logic vsync_d;

    // frame
    always_ff @(posedge clk, posedge reset) begin
        if (reset) vsync_d <= 1'b0;
        else vsync_d <= vsync;
    end

    wire vsync_rise = (~vsync_d && vsync);
    wire vsync_fall = (vsync_d && ~vsync);

    // fsm
    typedef enum logic [1:0] {
        IDLE,  // 대기
        WAIT_START,     // trigger가 들어온 후 프레임이 시작하기까지 대기
        CAPTURE  // 프레임 시작하면 캡쳐
    } state_t;

    state_t state;

    // state fsm
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            state             <= IDLE;
            frame_done_toggle <= 0;
        end else begin
            case (state)
                IDLE:       if (trig_rise) state <= WAIT_START;
                WAIT_START: if (vsync_fall) state <= CAPTURE;
                CAPTURE: begin
                    if (vsync_rise) begin
                        state <= IDLE;
                        frame_done_toggle <= ~frame_done_toggle;
                    end
                end
            endcase
        end
    end

    // data
    always_ff @(posedge clk, posedge reset) begin
        if (reset) begin
            byte_sel  <= 0;
            pixelData <= 0;
            we        <= 1'b0;
            wAddr     <= 0;
        end else begin
            if (state == WAIT_START) begin
                we       <= 0;
                byte_sel <= 0;
                wAddr    <= 0;
            end else if (state == CAPTURE) begin
                if (href) begin
                    if (byte_sel == 1'b0) begin
                        pixelData[15:8] <= data;
                        we              <= 1'b0;
                        byte_sel        <= 1'b1;
                    end else begin
                        we             <= 1'b1;
                        pixelData[7:0] <= data;
                        wAddr          <= wAddr + 1;
                        byte_sel       <= 1'b0;
                    end
                end else begin
                    we <= 1'b0;
                    byte_sel <= 1'b0;
                end
            end else begin
                we <= 1'b0;
                byte_sel <= 1'b0;
            end
        end
    end
endmodule
