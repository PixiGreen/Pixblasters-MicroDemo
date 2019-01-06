
`timescale 1 ns / 1 ps

module dvi_rx (
  input wire        rstbtn_n,   
  input wire [3:0]  TMDS,
  input wire [3:0]  TMDSB,

  output wire plllckd,
  output wire reset,

  output wire pix_clk,
  output wire hsync,
  output wire vsync,
  output wire de,
  output wire [7:0] red,
  output wire [7:0] green,
  output wire [7:0] blue,
  output wire data_vld,
  output wire data_rdy
);


  wire pclk, pclkx2, pclkx10, pllclk0;
  wire serdesstrobe;
  wire psalgnerr;      
  wire [29:0] sdata;
  wire blue_vld;
  wire green_vld;
  wire red_vld;
  wire blue_rdy;
  wire green_rdy;
  wire red_rdy;

  dvi_decoder dvi_rx0 (
    .tmdsclk_p   (TMDS[3]),
    .tmdsclk_n   (TMDSB[3]),
    .blue_p      (TMDS[0]),
    .green_p     (TMDS[1]),
    .red_p       (TMDS[2]),
    .blue_n      (TMDSB[0]),
    .green_n     (TMDSB[1]),
    .red_n       (TMDSB[2]),
    .exrst       (~rstbtn_n),

    .reset       (reset),
    .pclk        (pclk),
    .pclkx2      (pclkx2),
    .pclkx10     (pclkx10),
    .pllclk0     (pllclk0), 
    .pllclk1     (pllclk1), 
    .pllclk2     (pllclk2), 
    .pll_lckd    (plllckd),
    .tmdsclk     (tmdsclk),
    .serdesstrobe(serdesstrobe),
    .hsync       (hsync),
    .vsync       (vsync),
    .de          (de),

    .blue_vld    (blue_vld),
    .green_vld   (green_vld),
    .red_vld     (red_vld),
    .blue_rdy    (blue_rdy),
    .green_rdy   (green_rdy),
    .red_rdy     (red_rdy),

    .psalgnerr   (psalgnerr),

    .sdout       (sdata),
    .red         (red),
    .green       (green),
    .blue        (blue));

  assign pix_clk = pclk;


  assign data_vld = blue_vld & green_vld & red_vld;
  assign data_rdy = blue_rdy & green_rdy & red_rdy;

endmodule
