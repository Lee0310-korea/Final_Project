`timescale 1ns / 1ps

module multi_object_detect #(
    parameter H_PIXELS = 320,
    parameter MAX_OBJECTS = 64  // noise 고려해서 크게
) (
    // system clk
    input  logic                               clk,
    input  logic                               reset,
    // to analyzer
    input  logic                               vsync,
    input  logic [                        9:0] x_pixel,
    input  logic [                        9:0] y_pixel,
    input  logic                               DE,
    // color_detect_filter
    input  logic                               detect_pixel,
    // output
    output logic [                        9:0] object_x,
    output logic [                        9:0] object_y,
    output logic                               target_valid,
    output logic [$clog2(MAX_OBJECTS+1) - 1:0] target_cnt     // debug용
);

    localparam ID_WIDTH = $clog2(MAX_OBJECTS + 1);
    parameter NOISE_TH = 50;  // th보다 많은 pixel만 물체로 인식

    // 윗줄 line buffer
    (* ram_style = "distributed" *)
    logic [ID_WIDTH - 1:0] line_buffer[0:H_PIXELS - 1];

    logic [24:0] sum_x[0:MAX_OBJECTS-1];
    logic [24:0] sum_y[0:MAX_OBJECTS-1];
    logic [16:0] count[0:MAX_OBJECTS-1];
    logic active[0:MAX_OBJECTS-1];

    logic [ID_WIDTH:0] next_new_id;
    logic [ID_WIDTH-1:0] left_id;  // 왼쪽 pixel ID
    logic [ID_WIDTH-1:0] tmp_up_id;  // 윗줄 pixel ID
    logic [ID_WIDTH-1:0] tmp_current_id;  // 현재 pixel ID

    // union-find parent
    (* ram_style = "distributed" *)
    logic [ID_WIDTH-1:0] parent[0:MAX_OBJECTS-1];

    // merge
    logic [ID_WIDTH-1:0] merge_a, merge_b;
    logic [ID_WIDTH:0] merge_idx;


    // vsync edge detect
    logic vsync_d;
    always_ff @(posedge clk) begin
        if (reset) vsync_d <= 1'b1;
        else vsync_d <= vsync;
    end
    wire vsync_rise = (~vsync_d && vsync);

    typedef enum {
        COLLECT,
        MERGE,
        SEARCH,
        CALC,
        DONE
    } state_t;
    state_t                state;

    logic   [  ID_WIDTH:0] search_idx;
    logic   [ID_WIDTH-1:0] best_id;
    logic   [        16:0] max_size;
    logic   [  ID_WIDTH:0] obj_counter;


    // frame 제어 state
    always_ff @(posedge clk) begin
        if (reset) begin
            state        <= COLLECT;
            target_valid <= 0;
            object_x     <= 0;
            object_y     <= 0;
            target_cnt   <= 0;

            search_idx   <= 0;
            max_size     <= 0;
            best_id      <= 0;
            obj_counter  <= 0;
        end else begin
            target_valid <= 1'b0;
            case (state)
                COLLECT: begin
                    if (vsync_rise) begin
                        state     <= MERGE;
                        merge_idx <= MAX_OBJECTS - 1;
                    end
                end

                // union-find 
                MERGE: begin
                    if (merge_idx > 0) begin
                        merge_idx <= merge_idx - 1'b1;
                    end else begin
                        state       <= SEARCH;
                        search_idx  <= 1;
                        max_size    <= 0;
                        best_id     <= 0;
                        obj_counter <= 0;
                    end
                end

                SEARCH: begin
                    if (search_idx < MAX_OBJECTS) begin
                        if (active[search_idx] && count[search_idx] > NOISE_TH) begin
                            obj_counter <= obj_counter + 1;

                            if (count[search_idx] > max_size) begin
                                max_size <= count[search_idx];
                                best_id  <= search_idx[ID_WIDTH-1:0];
                            end
                        end
                        search_idx <= search_idx + 1;
                    end else begin
                        target_cnt <= obj_counter;

                        if (best_id != 0) begin
                            state <= CALC;
                        end else begin
                            target_valid <= 0;
                            state <= DONE;
                        end
                    end
                end

                CALC: begin
                    object_x     <= sum_x[best_id] / count[best_id];
                    object_y     <= sum_y[best_id] / count[best_id];
                    target_valid <= 1;
                    state        <= DONE;
                end

                DONE: begin
                    if (vsync == 0) begin
                        target_valid <= 0;
                        state <= COLLECT;
                    end
                end
            endcase
        end
    end

    // ID 결정 + Union
    always_comb begin
        tmp_up_id      = (y_pixel == 0 || x_pixel >= H_PIXELS) ? '0 : line_buffer[x_pixel];
        tmp_current_id = '0;

        merge_a = '0;
        merge_b = '0;

        if (state == COLLECT && DE && detect_pixel && x_pixel < H_PIXELS) begin
            if (tmp_up_id != 0) tmp_current_id = tmp_up_id;
            else if (left_id != 0) tmp_current_id = left_id;
            else if (next_new_id < MAX_OBJECTS)
                tmp_current_id = next_new_id[ID_WIDTH-1:0];

            if (tmp_up_id != 0 && left_id != 0 && tmp_up_id != left_id) begin
                merge_a = tmp_up_id;
                merge_b = left_id;
                tmp_current_id = (tmp_up_id < left_id) ? tmp_up_id : left_id;
            end
        end
    end

    // Datapath
    always_ff @(posedge clk) begin
        logic [ID_WIDTH-1:0] boss;
        if (reset) begin
            next_new_id <= 1;
            left_id     <= 0;

            for (int k = 0; k < MAX_OBJECTS; k++) begin
                sum_x[k]  <= 0;
                sum_y[k]  <= 0;
                count[k]  <= 0;
                active[k] <= 0;
                parent[k] <= k[ID_WIDTH-1:0];
            end
        end else begin

            if (state == DONE && vsync == 0) begin
                next_new_id <= 1;
                left_id     <= 0;
                for (int k = 0; k < MAX_OBJECTS; k++) begin
                    sum_x[k]  <= 0;
                    sum_y[k]  <= 0;
                    count[k]  <= 0;
                    active[k] <= 0;
                    parent[k] <= k[ID_WIDTH-1:0];
                end
            end

            if (state == MERGE && merge_idx > 0) begin
                boss = parent[merge_idx];

                if (parent[boss] != boss) boss = parent[boss];
                if (parent[boss] != boss) boss = parent[boss];
                if (parent[boss] != boss) boss = parent[boss];

                if (boss != merge_idx) begin
                    sum_x[boss] <= sum_x[boss] + sum_x[merge_idx];
                    sum_y[boss] <= sum_y[boss] + sum_y[merge_idx];
                    count[boss] <= count[boss] + count[merge_idx];

                    active[merge_idx] <= 1'b0;
                    sum_x[merge_idx] <= '0;
                    sum_y[merge_idx] <= '0;
                    count[merge_idx] <= '0;

                    parent[merge_idx] <= boss;
                end
            end

            if (state == COLLECT && DE) begin
                if (detect_pixel && (tmp_up_id == 0) && (left_id == 0) && (next_new_id < MAX_OBJECTS)) begin
                    next_new_id <= next_new_id + 1'b1;
                end

                if (tmp_current_id != 0) begin
                    sum_x[tmp_current_id]  <= sum_x[tmp_current_id] + x_pixel;
                    sum_y[tmp_current_id]  <= sum_y[tmp_current_id] + y_pixel;
                    count[tmp_current_id]  <= count[tmp_current_id] + 1;
                    active[tmp_current_id] <= 1;
                end

                line_buffer[x_pixel] <= tmp_current_id;

                if (x_pixel == H_PIXELS - 1) left_id <= 0;
                else left_id <= tmp_current_id;

                if (merge_a != 0 && merge_b != 0) begin
                    logic [ID_WIDTH-1:0] root_a, root_b;

                    root_a = parent[merge_a];
                    if (parent[root_a] != root_a) root_a = parent[root_a];
                    if (parent[root_a] != root_a) root_a = parent[root_a];

                    root_b = parent[merge_b];
                    if (parent[root_b] != root_b) root_b = parent[root_b];
                    if (parent[root_b] != root_b) root_b = parent[root_b];

                    if (root_a != root_b) begin
                        if (root_a < root_b) begin
                            if (parent[root_b] > root_a)
                                parent[root_b] <= root_a;
                        end else begin
                            if (parent[root_a] > root_b)
                                parent[root_a] <= root_b;
                        end
                    end
                end
            end
        end
    end

endmodule
