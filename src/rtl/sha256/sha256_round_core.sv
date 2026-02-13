module sha256_round_core (
  input  logic        clk,
  input  logic        rst_n,

  input  logic        valid_i,

  // 状態入力 (a..h)
  input  logic [31:0] a_i,
  input  logic [31:0] b_i,
  input  logic [31:0] c_i,
  input  logic [31:0] d_i,
  input  logic [31:0] e_i,
  input  logic [31:0] f_i,
  input  logic [31:0] g_i,
  input  logic [31:0] h_i,

  // ラウンド定数とメッセージワード
  input  logic [31:0] k_i,
  input  logic [31:0] w_i,

  output logic        valid_o,

  // 状態出力 (a'..h')
  output logic [31:0] a_o,
  output logic [31:0] b_o,
  output logic [31:0] c_o,
  output logic [31:0] d_o,
  output logic [31:0] e_o,
  output logic [31:0] f_o,
  output logic [31:0] g_o,
  output logic [31:0] h_o
);

  // ============================================================
  // Stage 1: 入力をレジスタ化 + 軽い論理（Σ/Ch/Maj）もレジスタ化
  //   ★重要：Stage2で参照する値はすべて同一サイクルのものに揃える
  // ============================================================

  logic        v1;
  logic [31:0] a1,b1,c1,d1,e1,f1,g1,h1;
  logic [31:0] k1, w1;

  // comb outputs from current inputs
  logic [31:0] s0_c, s1_c, ch_c, maj_c;

  // registered outputs (aligned with a1..h1)
  logic [31:0] s0_1, s1_1, ch_1, maj_1;

  sha256_l_sigma0 l_sigma0(.x(a_i), .y(s0_c));
  sha256_l_sigma1 l_sigma1(.x(e_i), .y(s1_c));
  sha256_ch     ch0   (.x(e_i), .y(f_i), .z(g_i), .ch(ch_c));
  sha256_maj    maj0  (.x(a_i), .y(b_i), .z(c_i), .maj(maj_c));

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      v1   <= 1'b0;

      a1   <= '0; b1 <= '0; c1 <= '0; d1 <= '0;
      e1   <= '0; f1 <= '0; g1 <= '0; h1 <= '0;

      k1   <= '0; w1 <= '0;

      s0_1 <= '0; s1_1 <= '0; ch_1 <= '0; maj_1 <= '0;
    end else begin
      v1   <= valid_i;

      a1   <= a_i; b1 <= b_i; c1 <= c_i; d1 <= d_i;
      e1   <= e_i; f1 <= f_i; g1 <= g_i; h1 <= h_i;

      k1   <= k_i;
      w1   <= w_i;

      // align Σ/Ch/Maj with the registered state above
      s0_1 <= s0_c;
      s1_1 <= s1_c;
      ch_1 <= ch_c;
      maj_1<= maj_c;
    end
  end

  // ============================================================
  // Stage 2: CSAで畳んで、CPAを減らす（現状の構造は維持）
  //   T1 = h + Σ1(e) + Ch + K + W   (5項)
  //   T2 = Σ0(a) + Maj              (2項)
  // ============================================================

  logic        v2;
  logic [31:0] a2,b2,c2,d2,e2,f2,g2,h2;

  // CSA intermediate
  logic [31:0] s_a0, c_a0;
  logic [31:0] s_a1, c_a1;
  logic [31:0] s_a2, c_a2;

  // final adds (CPA)
  logic [31:0] T1;
  logic [31:0] T2;
  logic [31:0] new_a;
  logic [31:0] new_e;

  // 5 terms: h1, s1_1, ch_1, k1, w1
  // compress 1: (h, s1, ch)
  sha256_csa sum_0(.x(h1), .y(s1_1), .z(ch_1), .csa_sum(s_a0), .csa_car(c_a0));

  // compress 2: (k, w, s_a0)
  sha256_csa sum_1(.x(k1), .y(w1), .z(s_a0), .csa_sum(s_a1), .csa_car(c_a1));

  // compress 3: (s_a1, c_a0<<1, c_a1<<1)
  sha256_csa sum_2(.x(s_a1), .y(c_a0 << 1), .z(c_a1 << 1), .csa_sum(s_a2), .csa_car(c_a2));

  // Final CPA(s)
  // NOTE: mod 2^32 arithmetic intended (natural 32-bit wrap)
  assign T1    = s_a2 + (c_a2 << 1);
  assign T2    = s0_1 + maj_1;
  assign new_a = T1 + T2;
  assign new_e = d1 + T1;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      v2 <= 1'b0;

      a2 <= '0; b2 <= '0; c2 <= '0; d2 <= '0;
      e2 <= '0; f2 <= '0; g2 <= '0; h2 <= '0;
    end else begin
      v2 <= v1;

      // shift state
      a2 <= new_a;
      b2 <= a1;
      c2 <= b1;
      d2 <= c1;

      e2 <= new_e;
      f2 <= e1;
      g2 <= f1;
      h2 <= g1;
    end
  end

  assign valid_o = v2;

  assign a_o = a2;
  assign b_o = b2;
  assign c_o = c2;
  assign d_o = d2;
  assign e_o = e2;
  assign f_o = f2;
  assign g_o = g2;
  assign h_o = h2;

endmodule
