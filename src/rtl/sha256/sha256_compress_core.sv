module sha256_compress_core (
  input  logic         clk,
  input  logic         rst_n,

  input  logic         start,
  input  logic [255:0] state_i,
  input  logic [511:0] block_i,

  output logic         busy,
  output logic         done,
  output logic [255:0] state_o
);

  // ---- K constants
  localparam logic [31:0] K [0:63] = '{
    32'h428a2f98,32'h71374491,32'hb5c0fbcf,32'he9b5dba5,
    32'h3956c25b,32'h59f111f1,32'h923f82a4,32'hab1c5ed5,
    32'hd807aa98,32'h12835b01,32'h243185be,32'h550c7dc3,
    32'h72be5d74,32'h80deb1fe,32'h9bdc06a7,32'hc19bf174,
    32'he49b69c1,32'hefbe4786,32'h0fc19dc6,32'h240ca1cc,
    32'h2de92c6f,32'h4a7484aa,32'h5cb0a9dc,32'h76f988da,
    32'h983e5152,32'ha831c66d,32'hb00327c8,32'hbf597fc7,
    32'hc6e00bf3,32'hd5a79147,32'h06ca6351,32'h14292967,
    32'h27b70a85,32'h2e1b2138,32'h4d2c6dfc,32'h53380d13,
    32'h650a7354,32'h766a0abb,32'h81c2c92e,32'h92722c85,
    32'ha2bfe8a1,32'ha81a664b,32'hc24b8b70,32'hc76c51a3,
    32'hd192e819,32'hd6990624,32'hf40e3585,32'h106aa070,
    32'h19a4c116,32'h1e376c08,32'h2748774c,32'h34b0bcb5,
    32'h391c0cb3,32'h4ed8aa4a,32'h5b9cca4f,32'h682e6ff3,
    32'h748f82ee,32'h78a5636f,32'h84c87814,32'h8cc70208,
    32'h90befffa,32'ha4506ceb,32'hbef9a3f7,32'hc67178f2
  };

  // ---- internal regs
  logic running;
  logic [5:0] round;

  logic [31:0] a,b,c,d,e,f,g,h;
  logic [31:0] a0,b0,c0,d0,e0,f0,g0,h0; // init state

  // W ring buffer (16 words)
  logic [31:0] W [0:15];

  assign busy = running;

  // ---- combinational per-round values
  logic [31:0] Wt;
  logic [31:0] T1, T2;
  logic [31:0] na,nb,nc,nd,ne,nf,ng,nh;

  // indices into ring buffer
  logic [3:0] r, r_m2, r_m7, r_m15, r_m16;

  logic [3:0] tmp_m2, tmp_m7, tmp_m15, tmp_m16;

    // ---- comb wires (module outputs)
  logic [31:0] s0_wm15, s1_wm2;
  logic [31:0] L0_a, L1_e;
  logic [31:0] ch_efg, maj_abc;

  // ring taps (stable wires)
  logic [31:0] w_r, w_m2, w_m7, w_m15, w_m16;

  assign w_r   = W[r];
  assign w_m2  = W[r_m2];
  assign w_m7  = W[r_m7];
  assign w_m15 = W[r_m15];
  assign w_m16 = W[r_m16];

  // ---- replace function calls by combinational modules
  sha256_s_sigma0 u_s0_wm15 (.x(w_m15), .y(s0_wm15));
  sha256_s_sigma1 u_s1_wm2  (.x(w_m2),  .y(s1_wm2));

  sha256_l_sigma0 u_L0_a (.x(a), .y(L0_a));
  sha256_l_sigma1 u_L1_e (.x(e), .y(L1_e));

  sha256_ch  u_ch  (.x(e), .y(f), .z(g), .ch(ch_efg));
  sha256_maj u_maj (.x(a), .y(b), .z(c), .maj(maj_abc));

  // ---- CSA trees
  logic [31:0] w_csa1_s, w_csa1_c;
  logic [31:0] w_csa2_s, w_csa2_c;
  logic [31:0] Wt_gen;

  sha256_csa u_w_csa1 (
    .x(s1_wm2), .y(w_m7), .z(s0_wm15),
    .csa_sum(w_csa1_s), .csa_car(w_csa1_c)
  );

  sha256_csa u_w_csa2 (
    .x(w_csa1_s),
    .y(w_csa1_c << 1),
    .z(w_m16),
    .csa_sum(w_csa2_s), .csa_car(w_csa2_c)
  );

  assign Wt_gen = w_csa2_s + (w_csa2_c << 1);

  // ---- T1 CSA tree: h + L1_e + ch + K + Wt
  logic [31:0] t1_csa1_s, t1_csa1_c;
  logic [31:0] t1_csa2_s, t1_csa2_c;
  logic [31:0] t1_csa3_s, t1_csa3_c;
  logic [31:0] T1_csa;

  sha256_csa u_t1_csa1 (
    .x(h), .y(L1_e), .z(ch_efg),
    .csa_sum(t1_csa1_s), .csa_car(t1_csa1_c)
  );

  sha256_csa u_t1_csa2 (
    .x(t1_csa1_s),
    .y(t1_csa1_c << 1),
    .z(K[round]),
    .csa_sum(t1_csa2_s), .csa_car(t1_csa2_c)
  );

  // Wt は round<16 だと素の W[r]、それ以外は Wt_gen
  logic [31:0] Wt_sel;
  assign Wt_sel = (round < 16) ? w_r : Wt_gen;

  sha256_csa u_t1_csa3 (
    .x(t1_csa2_s),
    .y(t1_csa2_c << 1),
    .z(Wt_sel),
    .csa_sum(t1_csa3_s), .csa_car(t1_csa3_c)
  );

  assign T1_csa = t1_csa3_s + (t1_csa3_c << 1);

  // ---- T2: L0_a + maj (2項なので普通にCPAでOK)
  logic [31:0] T2_cpa;
  assign T2_cpa = L0_a + maj_abc;

  // ---- next state (same as your logic)
  always_comb begin
    // index calc (あなたのままでもOK)
    r     = round[3:0];

    tmp_m2  = r - 4'd2;
    tmp_m7  = r - 4'd7;
    tmp_m15 = r - 4'd15;
    tmp_m16 = r - 4'd0;

    r_m2  = tmp_m2[3:0];
    r_m7  = tmp_m7[3:0];
    r_m15 = tmp_m15[3:0];
    r_m16 = tmp_m16[3:0];

    // outputs
    Wt = Wt_sel;     // <- 外向けが必要なら保持
    T1 = T1_csa;
    T2 = T2_cpa;

    nh = g;
    ng = f;
    nf = e;
    ne = d + T1;
    nd = c;
    nc = b;
    nb = a;
    na = T1 + T2;
  end

  integer i;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      running <= 1'b0;
      done    <= 1'b0;
      round   <= '0;
      state_o <= '0;
      {a,b,c,d,e,f,g,h} <= '0;
      {a0,b0,c0,d0,e0,f0,g0,h0} <= '0;
      for (i=0;i<16;i++) W[i] <= '0;
    end else begin
      done <= 1'b0;

      if (start && !running) begin
        running <= 1'b1;
        round   <= 6'd0;

        // state_i is packed as {a,b,c,d,e,f,g,h} in your earlier style
        {a,b,c,d,e,f,g,h} <= state_i;
        {a0,b0,c0,d0,e0,f0,g0,h0} <= state_i;

        // load W0..W15 from block_i (big-endian words)
        for (i=0;i<16;i++) begin
          W[i] <= block_i[511 - i*32 -: 32];
        end
      end else if (running) begin
        // update ring buffer for t>=16 (write Wt into current slot)
        if (round >= 16) begin
          W[r] <= Wt;
        end

        // advance state
        {a,b,c,d,e,f,g,h} <= {na,nb,nc,nd,ne,nf,ng,nh};

        if (round == 63) begin
          running <= 1'b0;
          done <= 1'b1;
          // IMPORTANT: use next-state (na..nh), not old a..h
          state_o <= {
            na + a0,
            nb + b0,
            nc + c0,
            nd + d0,
            ne + e0,
            nf + f0,
            ng + g0,
            nh + h0
          };
        end else begin
          round <= round + 6'd1;
        end
      end
    end
  end

endmodule
