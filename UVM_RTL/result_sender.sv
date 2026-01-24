`timescale 1ns / 1ps


module result_sender (
    input  logic       clk,
    input  logic       reset,
    // multi_object
    input  logic [9:0] object_x,
    input  logic [9:0] object_y,
    input  logic       target_valid,
    // uart
    output logic       tx_push,
    output logic [7:0] tx_push_data,
    input  logic       tx_fifo_full
);

    // valid edge trigger
    logic valid_d;

    always_ff @(posedge clk) begin
        if (reset) valid_d <= 1'b0;
        else valid_d <= target_valid;
    end
    wire valid_rise = target_valid & ~valid_d;

    // latch
    logic [9:0] lx, ly;

    typedef enum logic [2:0] {
        S_IDLE,
        S_B0,
        S_B1,
        S_B2,
        S_B3
    } state_t;

    state_t state;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            state        <= S_IDLE;
            tx_push      <= 1'b0;
            tx_push_data <= 8'h00;
            lx           <= '0;
            ly           <= '0;
        end else begin
            tx_push <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (valid_rise) begin
                        lx    <= object_x;
                        ly    <= object_y;
                        state <= S_B0;
                    end
                end
                S_B0:
                if (!tx_fifo_full) begin
                    tx_push      <= 1'b1;
                    tx_push_data <= lx[7:0];
                    state        <= S_B1;
                end

                S_B1:
                if (!tx_fifo_full) begin
                    tx_push      <= 1'b1;
                    tx_push_data <= {6'b0, lx[9:8]};
                    state        <= S_B2;
                end

                S_B2:
                if (!tx_fifo_full) begin
                    tx_push      <= 1'b1;
                    tx_push_data <= ly[7:0];
                    state        <= S_B3;
                end

                S_B3:
                if (!tx_fifo_full) begin
                    tx_push      <= 1'b1;
                    tx_push_data <= {6'b0, ly[9:8]};
                    state        <= S_IDLE;
                end
            endcase
        end
    end
endmodule
