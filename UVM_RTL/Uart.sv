`timescale 1ns / 1ps

module Uart #(
    parameter SYSCLK   = 100_000_000,
    parameter BAUDRATE = 9600
) (
    // global signals
    input  logic       clk,
    input  logic       rst,
    // external port
    output logic       tx,
    input  logic       rx,
    // inf to uart
    input  logic       tx_push,
    input  logic [7:0] tx_push_data,
    output logic       tx_fifo_full,
    //uart to inf
    input  logic       rx_pop,
    output logic [7:0] rx_pop_data,
    output logic       rx_fifo_empty,
    //status
    output logic       tx_busy
);

    logic       b_tick;

    // TX FIFO signals
    logic       tx_fifo_wr;
    logic       tx_fifo_rd;
    logic [7:0] tx_fifo_wdata;
    logic [7:0] tx_fifo_rdata;
    logic       tx_fifo_empty;
    logic       tx_fifo_full_int;

    // CPU → TX FIFO write side
    assign tx_fifo_wr    = tx_push && !tx_fifo_full_int;
    assign tx_fifo_wdata = tx_push_data;
    assign tx_fifo_full = tx_fifo_full_int;

    // UART TX → TX FIFO read side
    assign tx_fifo_rd    = (!tx_busy) && (!tx_fifo_empty);

    // RX FIFO signals
    logic       rx_fifo_wr;
    logic       rx_fifo_rd;
    logic [7:0] rx_fifo_wdata;
    logic [7:0] rx_fifo_rdata;
    logic       rx_fifo_empty_int;
    logic       rx_fifo_full;

    // uart_rx outputs
    logic [7:0] rx_data_int;
    logic       rx_done_int;

    // RX FIFO write
    assign rx_fifo_wr    = rx_done_int && !rx_fifo_full;
    assign rx_fifo_wdata = rx_data_int;
    assign rx_fifo_rd    = rx_pop && !rx_fifo_empty_int;

    // expose to CPU
    assign rx_pop_data   = rx_fifo_rdata;
    assign rx_fifo_empty = rx_fifo_empty_int;

    tick_gen #(
        .SYSCLK(SYSCLK),
        .FREQ  (BAUDRATE * 16)
    ) U_BAUD_TICK (
        .clk   (clk),
        .rst   (rst),
        .o_tick(b_tick)
    );

    fifo #(
        .DEPTH(16)
    ) U_FIFO_TX (
        .*,
        .wr   (tx_fifo_wr),
        .rd   (tx_fifo_rd),
        .wdata(tx_fifo_wdata),
        .rdata(tx_fifo_rdata),
        .full (tx_fifo_full_int),
        .empty(tx_fifo_empty)
    );

    uart_tx U_UART_TX (
        .*,
        .start_trig(!tx_busy && !tx_fifo_empty),
        .tx_data   (tx_fifo_rdata),
        .tx_busy   (tx_busy)
    );

    uart_rx U_UART_RX (
        .*,
        .rx_data(rx_data_int),
        .rx_done(rx_done_int)
    );

    fifo #(
        .DEPTH(16)
    ) U_FIFO_RX (
        .*,
        .wr   (rx_fifo_wr),
        .rd   (rx_fifo_rd),
        .wdata(rx_fifo_wdata),
        .rdata(rx_fifo_rdata),
        .full (rx_fifo_full),
        .empty(rx_fifo_empty_int)
    );



endmodule

module tick_gen #(
    parameter int unsigned SYSCLK = 100_000_000,
    parameter int unsigned FREQ   = 1_000_000
) (
    input  logic clk,
    input  logic rst,
    output logic o_tick
);

    logic [31:0] r_cnt;
    logic        r_tick;
    assign o_tick = r_tick;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            r_cnt  <= 32'd0;
            r_tick <= 1'b0;
        end else begin
            r_tick <= 1'b0;

            if (r_cnt >= (SYSCLK - FREQ)) begin
                r_cnt  <= r_cnt + FREQ - SYSCLK;
                r_tick <= 1'b1;
            end else begin
                r_cnt <= r_cnt + FREQ;
            end
        end
    end

endmodule


module fifo #(
    parameter DEPTH = 4
) (
    input  logic       clk,
    input  logic       rst,
    input  logic       wr,
    input  logic       rd,
    input  logic [7:0] wdata,
    output logic [7:0] rdata,
    output logic       full,
    output logic       empty
);

    wire [$clog2(DEPTH)-1:0] w_waddr, w_raddr;

    reg_file #(
        .DEPTH(DEPTH)
    ) U_REG_FILE (
        .clk(clk),
        .waddr(w_waddr),
        .raddr(w_raddr),
        .wr(~full & wr),
        .wdata(wdata),
        .rdata(rdata)
    );

    fifo_control_unit #(
        .DEPTH(DEPTH)
    ) U_FIFO_CU (
        .clk(clk),
        .rst(rst),
        .wr(wr),
        .rd(rd),
        .waddr(w_waddr),
        .raddr(w_raddr),
        .full(full),
        .empty(empty)
    );

endmodule

module fifo_control_unit #(
    parameter DEPTH = 4
) (
    input  logic                     clk,
    input  logic                     rst,
    input  logic                     wr,
    input  logic                     rd,
    output logic [$clog2(DEPTH)-1:0] waddr,
    output logic [$clog2(DEPTH)-1:0] raddr,
    output logic                     full,
    output logic                     empty
);

    logic [$clog2(DEPTH)-1:0] waddr_reg, waddr_next;
    logic [$clog2(DEPTH)-1:0] raddr_reg, raddr_next;
    logic full_reg, full_next;
    logic empty_reg, empty_next;

    assign waddr = waddr_reg;
    assign raddr = raddr_reg;
    assign full  = full_reg;
    assign empty = empty_reg;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            waddr_reg <= 0;
            raddr_reg <= 0;
            full_reg  <= 0;
            empty_reg <= 1;
        end else begin
            waddr_reg <= waddr_next;
            raddr_reg <= raddr_next;
            full_reg  <= full_next;
            empty_reg <= empty_next;
        end
    end

    always_comb begin
        waddr_next = waddr_reg;
        raddr_next = raddr_reg;
        full_next  = full_reg;
        empty_next = empty_reg;
        case ({
            wr, rd
        })
            2'b10: begin  // wr
                empty_next = 0;
                if (!full_reg) begin
                    waddr_next = waddr_reg + 1;
                    if (waddr_next == raddr_reg) begin
                        full_next = 1;
                    end
                end
            end
            2'b01: begin  // rd
                full_next = 0;
                if (!empty_reg) begin
                    raddr_next = raddr_reg + 1;
                    if (waddr_reg == raddr_next) begin
                        empty_next = 1;
                    end
                end
            end
            2'b11: begin  // wr & rd
                if (empty_reg) begin
                    waddr_next = waddr_reg + 1;
                    empty_next = 0;
                end else if (full_reg) begin
                    raddr_next = raddr_reg + 1;
                    full_next  = 0;
                end else begin
                    waddr_next = waddr_reg + 1;
                    raddr_next = raddr_reg + 1;
                end
            end
        endcase
    end

endmodule

module reg_file #(
    parameter DEPTH = 4
) (
    input                      clk,
    input  [$clog2(DEPTH)-1:0] waddr,
    input  [$clog2(DEPTH)-1:0] raddr,
    input                      wr,
    input  [              7:0] wdata,
    output [              7:0] rdata
);

    logic [7:0] ram[0:DEPTH-1];
    assign rdata = ram[raddr];

    always_ff @(posedge clk) begin
        if (wr) begin
            ram[waddr] <= wdata;
        end
    end

endmodule


module uart_tx (
    input  logic       clk,
    input  logic       rst,
    input  logic       b_tick,
    input  logic       start_trig,
    input  logic [7:0] tx_data,
    output logic       tx,
    output logic       tx_busy
);

    localparam [1:0] IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

    logic [1:0] state_reg, state_next;
    logic [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    logic [7:0] data_buf_reg, data_buf_next;
    logic [3:0] bit_cnt_reg, bit_cnt_next;
    logic tx_busy_reg, tx_busy_next;
    logic tx_reg, tx_next;

    assign tx = tx_reg;
    assign tx_busy = tx_busy_reg;

    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg      <= IDLE;
            b_tick_cnt_reg <= 0;
            bit_cnt_reg    <= 0;
            data_buf_reg   <= 0;
            tx_busy_reg    <= 0;
            tx_reg         <= 1;
        end else begin
            state_reg      <= state_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            data_buf_reg   <= data_buf_next;
            tx_busy_reg    <= tx_busy_next;
            tx_reg         <= tx_next;
        end
    end

    always_comb begin
        state_next      = state_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        data_buf_next   = data_buf_reg;
        tx_busy_next    = tx_busy_reg;
        tx_next         = tx_reg;
        case (state_reg)
            IDLE: begin
                tx_next      = 1;
                tx_busy_next = 0;
                if (start_trig) begin
                    data_buf_next = tx_data;
                    state_next    = START;
                    tx_busy_next = 1;
                end
            end
            START: begin
                tx_next = 0;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        state_next      = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                tx_next = data_buf_reg[0];
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        if (bit_cnt_reg == 7) begin
                            bit_cnt_next = 0;
                            state_next   = STOP;
                        end else begin
                            bit_cnt_next  = bit_cnt_reg + 1;
                            data_buf_next = data_buf_reg >> 1;
                        end
                        b_tick_cnt_next = 0;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                tx_next = 1;
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        state_next      = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule



module uart_rx (
    input  logic       clk,
    input  logic       rst,
    input  logic       rx,
    input  logic       b_tick,
    output logic [7:0] rx_data,
    output logic       rx_done
);

    localparam [1:0] IDLE = 2'b00, START = 2'b01, DATA = 2'b10, STOP = 2'b11;

    logic [1:0] state_reg, state_next;
    logic [4:0] b_tick_cnt_reg, b_tick_cnt_next;
    logic [3:0] bit_cnt_reg, bit_cnt_next;
    logic [7:0] rx_data_reg, rx_data_next;
    logic rx_done_reg, rx_done_next;

    assign rx_data = rx_data_reg;
    assign rx_done = rx_done_reg;

    // state SL
    always_ff @(posedge clk, posedge rst) begin
        if (rst) begin
            state_reg      <= 0;
            b_tick_cnt_reg <= 0;
            bit_cnt_reg    <= 0;
            rx_data_reg    <= 0;
            rx_done_reg    <= 0;
        end else begin
            state_reg      <= state_next;
            b_tick_cnt_reg <= b_tick_cnt_next;
            bit_cnt_reg    <= bit_cnt_next;
            rx_data_reg    <= rx_data_next;
            rx_done_reg    <= rx_done_next;
        end
    end

    // next CL
    always_comb begin
        state_next      = state_reg;
        b_tick_cnt_next = b_tick_cnt_reg;
        bit_cnt_next    = bit_cnt_reg;
        rx_data_next    = rx_data_reg;
        rx_done_next    = rx_done_reg;
        case (state_reg)
            IDLE: begin
                rx_done_next = 0;
                if (!rx) begin
                    state_next = START;
                end
                // if (b_tick) begin
                // end
            end
            START: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 7) begin
                        b_tick_cnt_next = 0;
                        state_next = DATA;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            DATA: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 15) begin
                        b_tick_cnt_next = 0;
                        rx_data_next = {rx, rx_data_reg[7:1]};
                        if (bit_cnt_reg == 7) begin
                            bit_cnt_next = 0;
                            state_next   = STOP;
                        end else begin
                            bit_cnt_next = bit_cnt_reg + 1;
                        end
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
            STOP: begin
                if (b_tick) begin
                    if (b_tick_cnt_reg == 23) begin
                        b_tick_cnt_next = 0;
                        rx_done_next = 1;
                        state_next = IDLE;
                    end else begin
                        b_tick_cnt_next = b_tick_cnt_reg + 1;
                    end
                end
            end
        endcase
    end

endmodule
