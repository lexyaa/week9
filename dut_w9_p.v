// Numerical Controlled Oscillator
module nco(     clk_gen,
                num,
                clk,
                rst_n    );

output          clk_gen   ;
input  [31:0]   num       ;
input           clk       ;
input           rst_n     ;

reg    [31:0]   cnt       ;
reg             clk_gen   ;
always @(posedge clk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
                 cnt      <= 32'd0;
                 clk_gen  <= 1'd0;
        end else begin
                 if(cnt >= num/2-1) begin
                           cnt      <= 32'd0;
                           clk_gen  <= ~clk_gen;
                 end else begin
                           cnt <= cnt + 1'b1;
                 end
        end
end

endmodule

//FND Decoder
module fnd_dec( o_seg,
                i_num );

output [6:0]    o_seg  ;
input  [3:0]    i_num  ;

reg    [6:0]    o_seg  ;
always @(*) begin
       case(i_num)
            4'd0  : o_seg = 7'b1111_110;
            4'd1  : o_seg = 7'b0110_000;
            4'd2  : o_seg = 7'b1101_101;
            4'd3  : o_seg = 7'b1111_001;
            4'd4  : o_seg = 7'b0110_011;
            4'd5  : o_seg = 7'b1011_011;
            4'd6  : o_seg = 7'b1011_111;
            4'd7  : o_seg = 7'b1110_000;
            4'd8  : o_seg = 7'b1111_111;
            4'd9  : o_seg = 7'b1110_011;
            4'd10 : o_seg = 7'b1110_111;
            4'd11 : o_seg = 7'b1111_111;
            4'd12 : o_seg = 7'b1001_110;
            4'd13 : o_seg = 7'b1111_110;
            4'd14 : o_seg = 7'b1001_111;
            4'd15 : o_seg = 7'b1000_111;
            default o_seg = 7'b0000_000;
        endcase
end

endmodule

// LED Display
module led_disp( o_seg,
                 o_seg_dp,
                 o_seg_enb,
                 i_six_digit_seg,
                 i_six_dp,
                 clk,
                 rst_n      );

output [5:0]     o_seg_enb           ;
output           o_seg_dp            ;
output [6:0]     o_seg               ;

input  [41:0]    i_six_digit_seg     ;
input  [5:0]     i_six_dp            ;
input            clk                 ;
input            rst_n               ;

wire             gen_clk             ;
nco              u_nco(
                 .clk_gen  ( gen_clk  ),
                 .num      ( 32'd5000 ),
                 .clk      ( clk      ),
                 .rst_n    ( rst_n    ));

reg    [3:0]     cnt_common_node     ;
always @(posedge gen_clk or negedge rst_n) begin
        if(rst_n == 1'b0) begin
                 cnt_common_node <= 4'd0;
        end else begin
                 if(cnt_common_node >= 4'd5) begin
                        cnt_common_node <= 4'd0;
                 end else begin
                        cnt_common_node <= cnt_common_node + 1'b1;
                 end
        end
end

reg     [5:0]    o_seg_enb           ;
always @(cnt_common_node) begin
         case(cnt_common_node)
                 4'd0 :  o_seg_enb = 6'b111110;
                 4'd1 :  o_seg_enb = 6'b111101;
                 4'd2 :  o_seg_enb = 6'b111011;
                 4'd3 :  o_seg_enb = 6'b110111;
                 4'd4 :  o_seg_enb = 6'b101111;
                 4'd5 :  o_seg_enb = 6'b011111;
                 default:o_seg_enb = 6'b111111;
         endcase
end

reg              o_seg_dp            ;
always @(cnt_common_node) begin
         case(cnt_common_node)
                 4'd0 :  o_seg_dp = i_six_dp[0];
                 4'd1 :  o_seg_dp = i_six_dp[1];
                 4'd2 :  o_seg_dp = i_six_dp[2];
                 4'd3 :  o_seg_dp = i_six_dp[3];
                 4'd4 :  o_seg_dp = i_six_dp[4];
                 4'd5 :  o_seg_dp = i_six_dp[5];
                 default:o_seg_dp = 1'b0;
         endcase
end

reg      [6:0]   o_seg               ;
always @(cnt_common_node) begin
         case(cnt_common_node)
                 4'd0 : o_seg = i_six_digit_seg[6:0];
                 4'd1 : o_seg = i_six_digit_seg[13:7];
                 4'd2 : o_seg = i_six_digit_seg[20:14];
                 4'd3 : o_seg = i_six_digit_seg[27:21];
                 4'd4 : o_seg = i_six_digit_seg[34:28];
                 4'd5 : o_seg = i_six_digit_seg[41:35];
                 default:o_seg = 7'b111_1110;
         endcase
end

endmodule


//IR_Rx
module ir_rx(   
                  o_data,
                  i_ir_rxb,
                  clk,
                  rst_n    );

output   [31:0]   o_data              ;

input             i_ir_rxb            ;
input             clk                 ;
input             rst_n               ;

parameter         IDLE     = 2'b00    ;
 // 9ms high 4.5ms low
parameter         LEADCODE = 2'b01    ;
 // Custom & Data Code
parameter         DATACODE = 2'b10    ;
 // 32-bit data
parameter         COMPLETE = 2'b11    ;

 //               1M Clock = 1us Reference Time
wire              clk_1M              ;
nco               u_nco(
                  .clk_gen   ( clk_1M ),
                  .num       ( 32'd50 ),
                  .clk       ( clk    ),
                  .rst_n     ( rst_n  ));

 //               Sequential Rx Bits
wire              ir_rx               ;
assign            ir_rx = ~i_ir_rxb   ;

reg      [1:0]    seg_rx              ;
always @(posedge clk_1M or negedge rst_n) begin
    if(rst_n == 1'b0) begin
             seg_rx <= 2'b00;
    end else begin
             seg_rx <= {seg_rx[0], ir_rx};
    end
end

 //               Count Signal Polarity (High & Low)
reg      [15:0]   cnt_h               ;
reg      [15:0]   cnt_l               ;
always @(posedge clk_1M or negedge rst_n) begin
    if(rst_n == 1'b0) begin
             cnt_h <= 16'd0;
             cnt_l <= 16'd0;
    end else begin
             case(seg_rx)
                     2'b00 : cnt_l <= cnt_l + 1;
                     2'b01 : begin
                           cnt_l <= 16'd0;
                           cnt_h <= 16'd0;
                     end
                     2'b11 : cnt_h <= cnt_h + 1;
             endcase
    end
end

 //               State Machine
reg      [1:0]    state               ;
reg      [5:0]    cnt32               ;
always @(posedge clk_1M or negedge rst_n) begin
    if(rst_n == 1'b0) begin
             state <= IDLE;
             cnt32 <= 6'd0;
    end else begin
             case(state)
                 IDLE: begin
                           state <= LEADCODE;
                           cnt32 <= 6'd0;
                 end
                 LEADCODE: begin
                           if(cnt_h >= 8500 && cnt_l >= 4000) begin
                                    state <= DATACODE;
                           end else begin
                                    state <= LEADCODE;
                           end
                 end
                 DATACODE: begin
                           if(seg_rx == 2'b01) begin
                                     cnt32 <= cnt32 + 1;
                           end else begin
                                     cnt32 <= cnt32;
                           end
                           if(cnt32 >= 6'd32 && cnt_l >= 1000) begin
                                    state <= COMPLETE;
                           end else begin
                                    state <= DATACODE;
                           end
                 end
                 COMPLETE: state <= IDLE;
             endcase
    end
end

 //               32bit Custom & Data Code
reg      [31:0]   data                ;
reg      [31:0]   o_data              ;
always @(posedge clk_1M or negedge rst_n) begin
    if(rst_n == 1'b0) begin
             data <= 32'd0;
    end else begin
             case(state)
                 DATACODE: begin
                           if(cnt_l >= 1000) begin
                                    data[32-cnt32] <= 1'b1;
                           end else begin
                                    data[32-cnt32] <= 1'b0;
                           end
                 end
                 COMPLETE: o_data <= data;
             endcase
    end
end

endmodule

module top(
                  o_seg,
                  o_seg_dp,
                  o_seg_enb,
                  i_ir_rxb,
                  clk,
                  rst_n     );

output   [6:0]    o_seg                ;
output            o_seg_dp             ;
output   [5:0]    o_seg_enb            ;

input             i_ir_rxb             ;
input             clk                  ;
input             rst_n                ;

wire     [31:0]   data                 ;
ir_rx             u_ir(   
                  .o_data   ( data     ),
                  .i_ir_rxb ( i_ir_rxb ),
                  .clk      ( clk      ),
                  .rst_n    ( rst_n    ));

wire     [6:0]    seg_0                   ;
fnd_dec           u_fnd_dec_0( 
                  .o_seg    ( seg_0       ),
                  .i_num    ( data[3:0]   ));

wire     [6:0]    seg_1                   ;
fnd_dec           u_fnd_dec_1( 
                  .o_seg    ( seg_1       ),
                  .i_num    ( data[7:4]   ));

wire     [6:0]    seg_2                   ;
fnd_dec           u_fnd_dec_2( 
                  .o_seg    ( seg_2       ),
                  .i_num    ( data[11:8]  ));

wire     [6:0]    seg_3                   ;
fnd_dec           u_fnd_dec_3( 
                  .o_seg    ( seg_3       ),
                  .i_num    ( data[15:12] ));

wire     [6:0]    seg_4                   ;
fnd_dec           u_fnd_dec_4( 
                  .o_seg    ( seg_4       ),
                  .i_num    ( data[19:16] ));

wire     [6:0]    seg_5                   ;
fnd_dec           u_fnd_dec_5( 
                  .o_seg    ( seg_5       ),
                  .i_num    ( data[23:20] ));

wire     [41:0]   six_digit_seg           ;
assign            six_digit_seg = {seg_5, seg_4, seg_3, seg_2, seg_1, seg_0};
led_disp          u_led_disp(
                  .o_seg           ( o_seg         ),
                  .o_seg_dp        ( o_seg_dp      ),
                  .o_seg_enb       ( o_seg_enb     ),
                  .i_six_digit_seg ( six_digit_seg ),
                  .i_six_dp        ( 6'd0          ),
                  .clk             ( clk           ),
                  .rst_n           ( rst_n         ));

endmodule
