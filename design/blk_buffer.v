module blk_buffer #(
   parameter HBLKS = 10,
   parameter VBLKS = 10,
   parameter PXS = 30 * 30
) (
   input clk_i,
   input rst_ni,
   input h_save_i,
   input v_save_i,
   input de_i,
   input [23:0] wd_i,

   output rx_o
);
   localparam DEPTH = $clog2(PXS * 512 * 255 + 1);
   localparam THRES = PXS * 256 * 255;

   reg h_clear_i, h_clear_r, h_clear_rr, h_clear_rrr;
   reg h_save_r, h_save_rr, h_save_rrr, h_save_rrrr, h_save_rrrrr;
   reg v_save_r, v_save_rr, v_save_rrr, v_save_rrrr, v_save_rrrrr, v_save_rrrrrr;
   always @(posedge clk_i) begin
      h_clear_i <= ~de_i || h_save_i;

      h_clear_r <= h_clear_i;
      h_save_r <= h_save_i;
      v_save_r <= v_save_i;

      h_clear_rr <= h_clear_r;
      h_save_rr <= h_save_r;
      v_save_rr <= v_save_r;

      h_clear_rrr <= h_clear_rr;
      h_save_rrr <= h_save_rr;
      v_save_rrr <= v_save_rr;

      h_save_rrrr <= h_save_rrr;
      v_save_rrrr <= v_save_rrr;

      h_save_rrrrr <= h_save_rrrr;
      v_save_rrrrr <= v_save_rrrr;

      v_save_rrrrrr <= v_save_rrrrr;
   end

   reg [$clog2(HBLKS+1)-1:0] cls_cnt;
   always @(posedge clk_i, negedge rst_ni) begin
      if (~rst_ni) begin
         cls_cnt <= 0;
      end else if (v_save_i) begin
         cls_cnt <= HBLKS;
      end else if (h_save_i && |cls_cnt) begin
         cls_cnt <= cls_cnt - 1;
      end
   end

   wire [47:0] p_1, p_2, p_3, p_4;
   wire [DEPTH-1:0] bacc0;
   shift_reg #(
      .DELAYS (HBLKS),
      .WIDTH (DEPTH)
   ) i_bacc (
      .clk_i (clk_i),
      .cen_i (~rst_ni || h_save_rrrrr),
      .d_i ({DEPTH{rst_ni}} & p_4[DEPTH-1:0]),
      .d_o (bacc0)
   );

   DSP48E1 #(
      .OPMODEREG (1),
      .AREG (1),
      .CREG (1),
      .MREG (0),
      .DREG (1), .ADREG (1)
   ) i_dsp_1 (
      .A ({22'b0,wd_i[23:16]}),
      .B (18'd109),
      .C ({{(48-DEPTH){1'b0}},bacc0}), // Unsigned extension desired!
      .PCIN (0),
      .PCOUT (p_1),
      .P (),

      // (h_save_i && ~|cls_cnt) == 0: XY = M, Z = 0
      // (h_save_i && ~|cls_cnt) == 1: XY = M, Z = C_r
      .OPMODE ((h_save_i && ~|cls_cnt) ? 7'b0110101 : 7'b0000101),
      .ALUMODE (4'b0000), // P_r <= Z + X + Y + CIN
      .INMODE (5'b00000), // M = A_r * B_r
      .CARRYINSEL (3'b000), // CIN = CARRYIN

      .D (0),
      .CEA1 (1), .CEA2 (1), .CEB1 (1), .CEB2 (1), .CEC (1), .CED (0), .CEM (0), .CEP (1), .CEAD (0),
      .CEALUMODE (1), .CECTRL (1), .CECARRYIN (1), .CEINMODE (1),
      .RSTA (~rst_ni), .RSTB (~rst_ni), .RSTC (~rst_ni), .RSTD (0), .RSTM (0), .RSTP (~rst_ni),
      .RSTCTRL (~rst_ni), .RSTALLCARRYIN (~rst_ni), .RSTALUMODE (~rst_ni), .RSTINMODE (~rst_ni),
      .CLK (clk_i),
      .ACIN (0), .BCIN (0), .CARRYIN (0), .CARRYCASCIN (0), .MULTSIGNIN (0),
      .ACOUT (), .BCOUT (), .CARRYOUT (), .CARRYCASCOUT (), .MULTSIGNOUT (),
      .PATTERNDETECT (), .PATTERNBDETECT (), .OVERFLOW (), .UNDERFLOW ()
   );

   DSP48E1 #(
      .AREG (1),
      .CREG (0),
      .MREG (1),
      .DREG (1), .ADREG (1)
   ) i_dsp_2 (
      .A ({22'b0,wd_i[15:8]}),
      .B (18'd37),
      .C (0),
      .PCIN (p_1),
      .PCOUT (p_2),
      .P (),

      // XY = M_r, Z = PCIN
      .OPMODE (7'b0010101),
      .ALUMODE (4'b0000), // P_r <= Z + X + Y + CIN
      .INMODE (5'b00000), // M_r <= A_r * B_r
      .CARRYINSEL (3'b000), // CIN = CARRYIN

      .D (0),
      .CEA1 (1), .CEA2 (1), .CEB1 (1), .CEB2 (1), .CEC (0), .CED (0), .CEM (1), .CEP (1), .CEAD (0),
      .CEALUMODE (1), .CECTRL (1), .CECARRYIN (1), .CEINMODE (1),
      .RSTA (~rst_ni), .RSTB (~rst_ni), .RSTC (0), .RSTD (0), .RSTM (~rst_ni), .RSTP (~rst_ni),
      .RSTCTRL (~rst_ni), .RSTALLCARRYIN (~rst_ni), .RSTALUMODE (~rst_ni), .RSTINMODE (~rst_ni),
      .CLK (clk_i),
      .ACIN (0), .BCIN (0), .CARRYIN (0), .CARRYCASCIN (0), .MULTSIGNIN (0),
      .ACOUT (), .BCOUT (), .CARRYOUT (), .CARRYCASCOUT (), .MULTSIGNOUT (),
      .PATTERNDETECT (), .PATTERNBDETECT (), .OVERFLOW (), .UNDERFLOW ()
   );

   DSP48E1 #(
      .AREG (2),
      .CREG (0),
      .MREG (1),
      .DREG (1), .ADREG (1)
   ) i_dsp_3 (
      .A ({22'b0,wd_i[7:0]}),
      .B (18'd366),
      .C (0),
      .PCIN (p_2),
      .PCOUT (p_3),
      .P (),

      // XY = M_r, Z = PCIN
      .OPMODE (7'b0010101),
      .ALUMODE (4'b0000), // P_r <= Z + X + Y + CIN
      .INMODE (5'b00000), // M_r <= A_rr * B_r
      .CARRYINSEL (3'b000), // CIN = CARRYIN

      .D (0),
      .CEA1 (1), .CEA2 (1), .CEB1 (1), .CEB2 (1), .CEC (0), .CED (0), .CEM (1), .CEP (1), .CEAD (0),
      .CEALUMODE (1), .CECTRL (1), .CECARRYIN (1), .CEINMODE (1),
      .RSTA (~rst_ni), .RSTB (~rst_ni), .RSTC (0), .RSTD (0), .RSTM (~rst_ni), .RSTP (~rst_ni),
      .RSTCTRL (~rst_ni), .RSTALLCARRYIN (~rst_ni), .RSTALUMODE (~rst_ni), .RSTINMODE (~rst_ni),
      .CLK (clk_i),
      .ACIN (0), .BCIN (0), .CARRYIN (0), .CARRYCASCIN (0), .MULTSIGNIN (0),
      .ACOUT (), .BCOUT (), .CARRYOUT (), .CARRYCASCOUT (), .MULTSIGNOUT (),
      .PATTERNDETECT (), .PATTERNBDETECT (), .OVERFLOW (), .UNDERFLOW ()
   );

   DSP48E1 #(
      .OPMODEREG (1),
      .CREG (0),
      .MREG (0),
      .DREG (1), .ADREG (1),
      .USE_MULT ("NONE")
   ) i_dsp_4 (
      .A (0),
      .B (0),
      .C (0),
      .PCIN (p_3),
      .PCOUT (),
      .P (p_4),

      // h_clear_rrr == 0: X = P_r, Y = 0, Z = PCIN
      // h_clear_rrr == 1: X = 0, Y = 0, Z = PCIN
      .OPMODE (h_clear_rrr ? 7'b0010000 : 7'b0010010),
      .ALUMODE (4'b0000), // P_r <= Z + X + Y + CIN
      .INMODE (5'b00010),
      .CARRYINSEL (3'b000), // CIN = CARRYIN

      .D (0),
      .CEA1 (1), .CEA2 (1), .CEB1 (1), .CEB2 (1), .CEC (0), .CED (0), .CEM (0), .CEP (1), .CEAD (0),
      .CEALUMODE (1), .CECTRL (1), .CECARRYIN (1), .CEINMODE (1),
      .RSTA (~rst_ni), .RSTB (~rst_ni), .RSTC (0), .RSTD (0), .RSTM (0), .RSTP (~rst_ni),
      .RSTCTRL (~rst_ni), .RSTALLCARRYIN (~rst_ni), .RSTALUMODE (~rst_ni), .RSTINMODE (~rst_ni),
      .CLK (clk_i),
      .ACIN (0), .BCIN (0), .CARRYIN (0), .CARRYCASCIN (0), .MULTSIGNIN (0),
      .ACOUT (), .BCOUT (), .CARRYOUT (), .CARRYCASCOUT (), .MULTSIGNOUT (),
      .PATTERNDETECT (), .PATTERNBDETECT (), .OVERFLOW (), .UNDERFLOW ()
   );

   wire p_4s = p_4 >= THRES; // _rrrrr
   reg [HBLKS-1:0] bt;
   always @(posedge clk_i, negedge rst_ni) begin
      if (~rst_ni) begin
         bt <= 0;
      end else if (h_save_rrrrr) begin
         bt <= {p_4s,bt[HBLKS-1:1]};
      end
   end

   wire [HBLKS-1:0] lbuf;
   shift_reg #(
      .DELAYS (VBLKS-1),
      .WIDTH (HBLKS)
   ) i_lbs (
      .clk_i (clk_i),
      .cen_i (~rst_ni || v_save_rrrrrr),
      .d_i ({HBLKS{rst_ni}} & bt),
      .d_o (lbuf)
   );

   reg [HBLKS-1:0] lbuf_r;
   always @(posedge clk_i, negedge rst_ni) begin
      if (~rst_ni) begin
         lbuf_r <= 0;
      end else if (v_save_rrrrrr) begin
         lbuf_r <= lbuf;
      end else if (h_save_i) begin
         lbuf_r <= {lbuf_r[0],lbuf_r[HBLKS-1:1]};
      end
   end

   assign rx_o = lbuf_r[0];

endmodule
