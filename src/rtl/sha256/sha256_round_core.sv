// sha256_round_core.sv

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

  // ----------------------------
  // helpers
  // ----------------------------
  function automatic logic [31:0] rotr32(input logic [31:0] x, input int s);
    rotr32 = (x >> s) | (x << (32 - s));
  endfunction

  function automatic logic [31:0] Sigma0(input logic [31:0] x);
    Sigma0 = rotr32(x, 2) ^ rotr32(x, 13) ^ rotr32(x, 22);
  endfunction

  function automatic logic [31:0] Sigma1(input logic [31:0] x);
    Sigma1 = rotr32(x, 6) ^ rotr32(x, 11) ^ rotr32(x, 25);
  endfunction

  function automatic logic [31:0] Ch(input logic [31:0] x, y, z);
    Ch = (x & y) ^ (~x & z);
  endfunction

  function automatic logic [31:0] Maj(input logic [31:0] x, y, z);
    Maj = (x & y) ^ (x & z) ^ (y & z);
  endfunction

  // 3:2 Carry-Save Adder (CSA) - carryは左シフトして足し込む
  function automatic logic [31:0] csa_sum(input logic [31:0] x, y, z);
    csa_sum = x ^ y ^ z;
  endfunction

  function automatic logic [31:0] csa_car(input logic [31:0] x, y, z);
    csa_car = (x & y) | (x & z) | (y & z);
  endfunction

  // ----------------------------
  // Stage 1 regs: 軽い論理（回転/XOR/AND系）を先に確定
  // ----------------------------
  logic        v1;
  logic [31:0] a1,b1,c1,d1,e1,f1,g1,h1;
  logic [31:0] s0_1, s1_1, ch_1, maj_1;
  logic [31:0] k1, w1;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      v1   <= 1'b0;
      a1   <= '0; b1 <= '0; c1 <= '0; d1 <= '0;
      e1   <= '0; f1 <= '0; g1 <= '0; h1 <= '0;
      s0_1 <= '0; s1_1 <= '0; ch_1 <= '0; maj_1 <= '0;
      k1   <= '0; w1   <= '0;
    end else begin
      v1   <= valid_i;

      a1   <= a_i; b1 <= b_i; c1 <= c_i; d1 <= d_i;
      e1   <= e_i; f1 <= f_i; g1 <= g_i; h1 <= h_i;

      s0_1 <= Sigma0(a_i);
      s1_1 <= Sigma1(e_i);
      ch_1 <= Ch(e_i, f_i, g_i);
      maj_1<= Maj(a_i, b_i, c_i);

      k1   <= k_i;
      w1   <= w_i;
    end
  end

  // ----------------------------
  // Stage 2: CSAで多項加算を畳んで、最後にCPAを1回だけ
  //   T1 = h + Σ1(e) + Ch + K + W   (5項)
  //   T2 = Σ0(a) + Maj              (2項)
  // ----------------------------
  logic        v2;
  logic [31:0] a2,b2,c2,d2,e2,f2,g2,h2;

  // CSA intermediate
  logic [31:0] s_a0, c_a0;
  logic [31:0] s_a1, c_a1;
  logic [31:0] s_a2, c_a2;

  // final adds (CPA) --- DSP禁止ヒント
  (* use_dsp = "no" *) logic [31:0] T1;
  (* use_dsp = "no" *) logic [31:0] T2;
  (* use_dsp = "no" *) logic [31:0] new_a;
  (* use_dsp = "no" *) logic [31:0] new_e;

  always_comb begin
    // CSA tree for 5 terms: h1, s1_1, ch_1, k1, w1

    // 1st compress (h, s1, ch)
    s_a0 = csa_sum(h1, s1_1, ch_1);
    c_a0 = csa_car(h1, s1_1, ch_1);

    // 2nd compress (k, w, s_a0)
    s_a1 = csa_sum(k1, w1, s_a0);
    c_a1 = csa_car(k1, w1, s_a0);

    // 3rd compress (s_a1, c_a0<<1, c_a1<<1)
    s_a2 = csa_sum(s_a1, (c_a0 << 1), (c_a1 << 1));
    c_a2 = csa_car(s_a1, (c_a0 << 1), (c_a1 << 1));

    // final CPA only once
    T1 = s_a2 + (c_a2 << 1);

    // T2 is only 2 terms: we can just add (CPA once)
    T2 = s0_1 + maj_1;

    new_a = T1 + T2;
    new_e = d1 + T1;
  end

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
