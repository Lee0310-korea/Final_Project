`timescale 1ns / 1ps

module analyzer_addr (
    input  logic                         clk,
    input  logic                         reset,
    input  logic                         frame_done_toggle,
    // to mux
    output logic [$clog2(320*240) - 1:0] analyze_addr,
    output logic                         addr_sel,
    // to multi_object_detect
    output logic [                  9:0] x_label,
    output logic [                  9:0] y_label,
    output logic                         DE,
    output logic                         vsync
);

    localparam H_PIXELS = 320;
    localparam V_PIXELS = 240;
    localparam FRAME_SIZE = H_PIXELS * V_PIXELS;

    // edge detector
    logic tick1, tick2;
    always_ff @(posedge clk) begin
        if (reset) begin
            tick1 <= 0;
            tick2 <= 0;
        end else begin
            tick1 <= frame_done_toggle;
            tick2 <= tick1;
        end
    end

    wire tick_edge = tick1 ^ tick2;

    // state
    typedef enum {
        IDLE,
        ADDR
    } state_t;
    state_t state;

    always_ff @(posedge clk) begin
        if (reset) state <= IDLE;
        else begin
            case (state)
                IDLE: begin
                    if (tick_edge) state <= ADDR;
                end
                ADDR: begin
                    if (analyze_addr == FRAME_SIZE - 1) state <= IDLE;
                end
            endcase
        end
    end

    logic [9:0] x_comb, y_comb;

    always_ff @(posedge clk) begin
        if (reset) begin
            analyze_addr <= 0;
            addr_sel     <= 0;

            x_comb       <= 0;
            y_comb       <= 0;
        end else begin
            case (state)
                IDLE: begin
                    analyze_addr <= 0;
                    addr_sel     <= 0;

                    x_comb       <= 0;
                    y_comb       <= 0;
                end

                ADDR: begin
                    addr_sel <= 1'b1;

                    if (addr_sel == 1'b1) begin
                        if (analyze_addr != FRAME_SIZE - 1) begin
                            analyze_addr <= analyze_addr + 1'b1;

                            if (x_comb == H_PIXELS - 1) begin
                                x_comb <= 0;
                                if (y_comb == V_PIXELS - 1) begin
                                    y_comb <= 0;
                                end else begin
                                    y_comb <= y_comb + 1;
                                end
                            end else begin
                                x_comb <= x_comb + 1;
                            end
                        end
                    end
                end
            endcase
            if (state == ADDR && analyze_addr == FRAME_SIZE - 1) begin
                addr_sel <= 0;
            end
        end
    end

    logic addr_sel_d;

    always_ff @(posedge clk) begin
        if (reset) begin
            addr_sel_d <= 0;
            x_label    <= 0;
            y_label    <= 0;
        end else begin
            addr_sel_d <= addr_sel;
            x_label    <= x_comb;
            y_label    <= y_comb;
        end
    end

    assign DE = addr_sel_d;
    assign vsync = ~(addr_sel | addr_sel_d);

endmodule
