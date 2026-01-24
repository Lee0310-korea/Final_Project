`timescale 1ns / 1ps



module ImgMemReader_Debug (
    input  logic                         clk,
    input  logic                         reset,

    input  logic                         DE,
    input  logic [                  9:0] x_pixel,
    input  logic [                  9:0] y_pixel,

    output logic [$clog2(320*240)-1 : 0] addr,
    input  logic [                 15:0] imgData,

    input  logic [                  9:0] object_x,
    input  logic [                  9:0] object_y,
    input  logic                         target_valid,

    input  logic                         analysis_busy, // ★ 추가: addr_sel 연결(분석중=1)

    output logic [                  3:0] r_port,
    output logic [                  3:0] g_port,
    output logic [                  3:0] b_port
);

    // -------------------------------------------------------------
    // 1) 주소 요청 (T)
    // -------------------------------------------------------------
    logic en_req;
    assign en_req = DE && (x_pixel < 320) && (y_pixel < 240);

    // 320*y + x (곱셈 LUT 줄이고 싶으면 shift-add로 바꿔도 됨)
    // 320 = 256 + 64 => (y<<8) + (y<<6) + x
    logic [$clog2(320*240)-1:0] y_mul_320;
    assign y_mul_320 = ({y_pixel, 8'b0} + {y_pixel, 6'b0});
    assign addr      = en_req ? (y_mul_320 + x_pixel) : '0;

    // -------------------------------------------------------------
    // 2) 파이프라인 (T -> T+1)
    // -------------------------------------------------------------
    logic       en_d;
    logic [9:0] x_d, y_d;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            en_d <= 1'b0;
            x_d  <= '0;
            y_d  <= '0;
        end else begin
            en_d <= en_req;
            x_d  <= x_pixel;
            y_d  <= y_pixel;
        end
    end

    // -------------------------------------------------------------
    // 3) 결과 좌표/valid 래치 (★ 핵심)
    // -------------------------------------------------------------
    logic [9:0] obj_x_hold, obj_y_hold;
    logic       obj_valid_hold;

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            obj_x_hold     <= '0;
            obj_y_hold     <= '0;
            obj_valid_hold <= 1'b0;
        end else begin
            // 새 분석 시작하면 이전 표시 삭제
            if (analysis_busy) begin
                obj_valid_hold <= 1'b0;
            end
            // 결과가 나오면 래치해서 유지
            else if (target_valid) begin
                obj_x_hold     <= object_x;
                obj_y_hold     <= object_y;
                obj_valid_hold <= 1'b1;
            end
        end
    end

    // -------------------------------------------------------------
    // 4) 십자 표시 계산 (T+1)
    // -------------------------------------------------------------
    logic [10:0] dx, dy;
    assign dx = (x_d > obj_x_hold) ? (x_d - obj_x_hold) : (obj_x_hold - x_d);
    assign dy = (y_d > obj_y_hold) ? (y_d - obj_y_hold) : (obj_y_hold - y_d);

    logic hit_cross;
    assign hit_cross = obj_valid_hold && en_d &&
                       ( (dy == 0 && dx <= 2) || (dx == 0 && dy <= 2) );

    // -------------------------------------------------------------
    // 5) 최종 출력 (T+1)
    // -------------------------------------------------------------
    always_comb begin
        if (!en_d) begin
            r_port = 4'h0;
            g_port = 4'h0;
            b_port = 4'h0;
        end else if (hit_cross) begin
            r_port = 4'h0;
            g_port = 4'hF;
            b_port = 4'h0;
        end else begin
            r_port = imgData[15:12];
            g_port = imgData[10:7];
            b_port = imgData[4:1];
        end
    end

endmodule


// module ImgMemReader_Debug (
//     input  logic                         clk,    // [추가] 파이프라인용
//     input  logic                         reset,  // [추가]

//     input  logic                         DE,     // vgaDecoder에서 들어오는 신호 (이게 T시점인지 T+1시점인지 중요, 아래 설명 참고)
//     input  logic [                  9:0] x_pixel, // vgaDecoder에서 온 좌표
//     input  logic [                  9:0] y_pixel,

//     output logic [$clog2(320*240)-1 : 0] addr,    // Frame Buffer로 갈 주소
//     input  logic [                 15:0] imgData, // Frame Buffer에서 온 데이터 (1clk 늦음)

//     input  logic [                  9:0] object_x,
//     input  logic [                  9:0] object_y,
//     input  logic                         target_valid,

//     output logic [                  3:0] r_port,
//     output logic [                  3:0] g_port,
//     output logic [                  3:0] b_port
// );

//     // -------------------------------------------------------------
//     // 1. 주소 요청 (T 시점): "메모리야 데이터 줘"
//     // -------------------------------------------------------------
//     // x_pixel, y_pixel이 들어오자마자 바로 주소 계산해서 보냄
//     logic en_req;
//     assign en_req = DE && (x_pixel < 320) && (y_pixel < 240);
//     assign addr   = en_req ? (320 * y_pixel + x_pixel) : '0;

//     // -------------------------------------------------------------
//     // 2. 파이프라인 레지스터 (T -> T+1): 좌표와 Enable 신호를 1클럭 늦춤
//     // -------------------------------------------------------------
//     logic       en_d;
//     logic [9:0] x_d, y_d;

//     always_ff @(posedge clk or posedge reset) begin
//         if (reset) begin
//             en_d <= 1'b0;
//             x_d  <= '0;
//             y_d  <= '0;
//         end else begin
//             en_d <= en_req;  // 지금 요청한 픽셀이 유효한가?
//             x_d  <= x_pixel; // 좌표도 같이 넘겨서 나중에 십자 그릴 때 씀
//             y_d  <= y_pixel;
//         end
//     end

//     // -------------------------------------------------------------
//     // 3. 십자 표시 계산 (T+1 시점): 지연된 좌표(x_d, y_d) 사용
//     // -------------------------------------------------------------
//     logic [10:0] dx, dy;
//     // imgData가 도착한 시점의 좌표(x_d, y_d)와 물체 좌표를 비교해야 함
//     assign dx = (x_d > object_x) ? (x_d - object_x) : (object_x - x_d);
//     assign dy = (y_d > object_y) ? (y_d - object_y) : (object_y - y_d);

//     logic hit_cross;
//     assign hit_cross = target_valid && en_d &&
//                        ( (dy == 0 && dx <= 2) || (dx == 0 && dy <= 2) );

//     // -------------------------------------------------------------
//     // 4. 최종 출력 (T+1 시점)
//     // -------------------------------------------------------------
//     // imgData는 T+1 시점에 도착하므로, en_d(T+1)와 타이밍이 딱 맞음
//     always_comb begin
//         if (!en_d) begin
//             r_port = 4'h0;
//             g_port = 4'h0;
//             b_port = 4'h0;
//         end else if (hit_cross) begin
//             r_port = 4'h0;
//             g_port = 4'hF; // 초록색 십자
//             b_port = 4'h0;
//         end else begin
//             r_port = imgData[15:12];
//             g_port = imgData[10:7];
//             b_port = imgData[4:1];
//         end
//     end

// endmodule


