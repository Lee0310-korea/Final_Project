`timescale 1ns / 1ps

module color_detect_filter (
    input  logic [15:0] rgb_data,
    input  logic [ 1:0] filter_sel,
    output logic        detect_pixel,
    output logic [15:0] debug_data
);

// RED 검출용 (RGB565 입력)
logic [4:0] r5;
logic [5:0] g6;
logic [4:0] b5;

assign r5 = rgb_data[15:11];
assign g6 = rgb_data[10:5];
assign b5 = rgb_data[4:0];

// 스케일 맞추기: r/b를 6bit로(<<1)
logic [5:0] r6, b6;
assign r6 = {r5, 1'b0};   // 0~62
assign b6 = {b5, 1'b0};   // 0~62

// 밝기(sum) : 0~(62+63+62)=187
logic [7:0] sum_rgb;
assign sum_rgb = {2'b00, r6} + {2'b00, g6} + {2'b00, b6};

// 채도 근사(sat = max-min) (6bit 스케일 기준)
logic [5:0] max_c6, min_c6;
always_comb begin
    max_c6 = r6;
    if (g6 > max_c6) max_c6 = g6;
    if (b6 > max_c6) max_c6 = b6;

    min_c6 = r6;
    if (g6 < min_c6) min_c6 = g6;
    if (b6 < min_c6) min_c6 = b6;
end
logic [5:0] sat6;
assign sat6 = max_c6 - min_c6;

// 차이(diff)
logic [6:0] rg_diff, rb_diff;
assign rg_diff = (r6 >= g6) ? ({1'b0,r6} - {1'b0,g6}) : 7'd0;
assign rb_diff = (r6 >= b6) ? ({1'b0,r6} - {1'b0,b6}) : 7'd0;

// (G+B) 합
logic [7:0] gb_sum;
assign gb_sum = {2'b00, g6} + {2'b00, b6};

// ---- 튜닝 파라미터(시작점) ----
// 어두운 빨강 살리고 싶으면 SUM_MIN을 낮추되, 너무 낮추면 검정/그림자 노이즈 증가
localparam [7:0] RED_SUM_MIN = 8'd35;   // (대략) 5bit sum 10~12 정도 느낌

// 회색/흰색 컷(채도)
localparam [5:0] RED_SAT_MIN = 6'd4;

// 분홍/보라 컷(B 상한) : 너무 낮추면 어두운 빨강도 잘릴 수 있음
localparam [5:0] RED_B6_MAX  = 6'd24;   // b5=12 -> b6=24

// 노랑/나무 컷 핵심: R이 (G+B)보다 얼마나 더 우세해야 하는지
localparam [7:0] RED_DOM_K   = 8'd6;

// 기본 마진
localparam [6:0] RED_RG_MIN  = 7'd6;
localparam [6:0] RED_RB_MIN  = 7'd18;

// 최종
logic detect_red;
assign detect_red =
    (sum_rgb >= RED_SUM_MIN) &&
    (sat6    >= RED_SAT_MIN) &&
    (b6      <= RED_B6_MAX ) &&
    (rg_diff >= RED_RG_MIN ) &&
    (rb_diff >= RED_RB_MIN ) &&
    ({2'b00, r6} >= (gb_sum + RED_DOM_K));

    // GREEN/BLUE는 그대로
    logic detect_green;
    assign detect_green = (g6 > 6'd36) && (r5 < 5'd18) && (b5 < 5'd18);

    logic detect_blue;
    assign detect_blue = (b5 > 5'd18) && (r5 < 5'd18) && (g6 < 6'd18);

    always_comb begin
        detect_pixel = 1'b0;
        debug_data   = rgb_data;
        case (filter_sel)
            2'b01: begin
                detect_pixel = detect_red;
                debug_data   = detect_red ? 16'hFFFF : 16'h0000;
            end
            2'b10: begin
                detect_pixel = detect_green;
                debug_data   = detect_green ? 16'hFFFF : 16'h0000;
            end
            2'b11: begin
                detect_pixel = detect_blue;
                debug_data   = detect_blue ? 16'hFFFF : 16'h0000;
            end
            default: begin
                detect_pixel = 1'b0;
                debug_data   = rgb_data;
            end
        endcase
    end

endmodule

// module color_detect_filter (
//     input  logic [15:0] rgb_data,
//     input  logic [ 1:0] filter_sel,
//     output logic        detect_pixel,
//     output logic [15:0] debug_data
// );

//     logic [4:0] r_data;
//     logic [5:0] g_data;
//     logic [4:0] b_data;

//     assign r_data = rgb_data[15:11];
//     assign g_data = rgb_data[10:5];
//     assign b_data = rgb_data[4:0];


//     // -----------------------------
//     // [RED] 개선?�� 조건 (밝기/채도/?��?��)
//     // -----------------------------
//     // ?��?��?�� ?��?��미터?��
//     localparam int unsigned RED_SUM_MIN   = 10'd25; // 밝기 ?��?��(?��출수�? ?��?��?�� 빨강?�� ?��?��)
//     localparam int unsigned RED_SAT_MIN   = 6'd3;   // 채도 ?��?��(?��출수�? ?��?��/?��?�� ?���? 증�?)
//     localparam int unsigned RED_RG_MARGIN = 5'd4;   // r�? g보다 ?��마나 커야 ?��?���?(?��격도)
//     localparam int unsigned RED_RB_MARGIN = 5'd10;   // r�? b보다 ?��마나 커야 ?��?���?(보라/분홍 �?)

//     localparam [4:0] RED_B_MAX = 5'd12;
//     localparam [6:0] RED_GB_DOM_K = 7'd3;


//     // 밝기 근사(sum): r(5) + g(6) + b(5) => 최�? 31+63+31=125 (7bit�? 충분)
//     logic [6:0] sum_rgb;
//     assign sum_rgb = {2'b00, r_data} + {1'b0, g_data} + {2'b00, b_data};

//     // 채도 근사: max-min (g?�� 6bit?�� r/b?? ?���??�� ?���?)
//     // 비교?��?���? g�? 5bit�? 축소(g5 = g>>1)?��?�� r/b?? 맞춤
//     logic [4:0] g5;
//     assign g5 = g_data[5:1];

//     logic [4:0] max_c, min_c;
//     always_comb begin
//         // max
//         max_c = r_data;
//         if (g5 > max_c) max_c = g5;
//         if (b_data > max_c) max_c = b_data;

//         // min
//         min_c = r_data;
//         if (g5 < min_c) min_c = g5;
//         if (b_data < min_c) min_c = b_data;
//     end

//     logic [5:0] sat;
//     assign sat = {1'b0, max_c} - {1'b0, min_c}; // 0~31

//     logic [6:0] gb_sum;
//     assign gtb_sum = {2'b00, g5} + {2'b00+b_data};

//     logic detect_red;
//     assign detect_red =
//         (sum_rgb >= RED_SUM_MIN[6:0]) &&         // ?���? ?��?��?�� ?��?? �?
//         (sat     >= RED_SAT_MIN)     &&           // ?���? ?��?�� ?��??(?��?��/?��?��) �?
//         (r_data  >= (g5 + RED_RG_MARGIN)) &&
//         (r_data  >= (b_data + RED_RB_MARGIN))&&

//         (b_data <= RED_B_MAX) &&
//         ({2'b00, r_data} >= (gb_sum + RED_GB_DOM_K));

//     // -----------------------------
//     // [GREEN/BLUE] 기존 조건 ?���?
//     // -----------------------------
//     logic detect_green;
//     assign detect_green = (g_data > 6'd36) && (r_data < 5'd18) && (b_data < 5'd18);

//     logic detect_blue;
//     assign detect_blue = (b_data > 5'd18) && (r_data < 5'd18) && (g_data < 6'd18);

//     // -----------------------------
//     // 출력/?��버그
//     // -----------------------------
//     always_comb begin
//         detect_pixel = 1'b0;
//         debug_data   = rgb_data;
//         case (filter_sel)
//             2'b01: begin
//                 detect_pixel = detect_red;
//                 debug_data   = detect_red ? 16'hFFFF : 16'h0000;
//             end
//             2'b10: begin
//                 detect_pixel = detect_green;
//                 debug_data   = detect_green ? 16'hFFFF : 16'h0000;
//             end
//             2'b11: begin
//                 detect_pixel = detect_blue;
//                 debug_data   = detect_blue ? 16'hFFFF : 16'h0000;
//             end
//             default: begin
//                 detect_pixel = 1'b0;
//                 debug_data   = rgb_data;
//             end
//         endcase
//     end

// endmodule



// module color_detect_filter (
//     // rgb data
//     input  logic [15:0] rgb_data,
//     input  logic [ 1:0] filter_sel,
//     output logic        detect_pixel,
//     // debug
//     output logic [15:0] debug_data
// );

//     logic [4:0] r_data;
//     logic [5:0] g_data;
//     logic [4:0] b_data;

//     assign r_data = rgb_data[15:11];
//     assign g_data = rgb_data[10:5];
//     assign b_data = rgb_data[4:0];

//     logic detect_red;
//     assign detect_red = (r_data > 5'd16) && (g_data < 6'd25) && (b_data < 5'd20);

//     logic detect_green;
//     assign detect_green = (g_data > 6'd36) && (r_data < 5'd18) && (b_data < 5'd18);

//     logic detect_blue;
//     assign detect_blue = (b_data > 5'd18) && (r_data < 5'd18) && (g_data < 6'd18);

//     always_comb begin
//         detect_pixel = 1'b0;
//         debug_data   = rgb_data;
//         case (filter_sel)
//             2'b01: begin
//                 detect_pixel = detect_red;
//                 debug_data   = detect_red ? 16'hFFFF : 16'h0000;
//             end
//             2'b10: begin
//                 detect_pixel = detect_green;
//                 debug_data   = detect_green ? 16'hFFFF : 16'h0000;
//             end
//             2'b11: begin
//                 detect_pixel = detect_blue;
//                 debug_data   = detect_blue ? 16'hFFFF : 16'h0000;
//             end
//             default: begin
//                 detect_pixel = 0;
//                 debug_data   = rgb_data;
//             end
//         endcase
//     end
// endmodule
