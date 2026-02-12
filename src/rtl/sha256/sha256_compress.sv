// sha256_compress.sv

module sha256_compress (
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

  // ---- helpers（可変シフトは避けたいなら固定回転版にしてOK）
  function automatic logic [31:0] rotr(input logic [31:0] x, input int s);
    rotr = (x >> s) | (x << (32-s));
  endfunction
  function automatic logic [31:0] Sigma0(input logic [31:0] x);
    Sigma0 = rotr(x,2) ^ rotr(x,13) ^ rotr(x,22);
  endfunction
  function automatic logic [31:0] Sigma1(input logic [31:0] x);
    Sigma1 = rotr(x,6) ^ rotr(x,11) ^ rotr(x,25);
  endfunction
  function automatic logic [31:0] sigma0(input logic [31:0] x);
    sigma0 = rotr(x,7) ^ rotr(x,18) ^ (x >> 3);
  endfunction
  function automatic logic [31:0] sigma1(input logic [31:0] x);
    sigma1 = rotr(x,17) ^ rotr(x,19) ^ (x >> 10);
  endfunction
  function automatic logic [31:0] Ch(input logic [31:0] x,y,z);
    Ch = (x & y) ^ (~x & z);
  endfunction
  function automatic logic [31:0] Maj(input logic [31:0] x,y,z);
    Maj = (x & y) ^ (x & z) ^ (y & z);
  endfunction

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

  always_comb begin
    r     = round[3:0];

    tmp_m2  = r - 4'd2;
    tmp_m7  = r - 4'd7;
    tmp_m15 = r - 4'd15;
    tmp_m16 = r - 4'd0;

    r_m2  = tmp_m2[3:0];
    r_m7  = tmp_m7[3:0];
    r_m15 = tmp_m15[3:0];
    r_m16 = tmp_m16[3:0];


    if (round < 16) begin
      Wt = W[r]; // 0..15はそのまま
    end else begin
      // Wt = σ1(W[t-2]) + W[t-7] + σ0(W[t-15]) + W[t-16]
      Wt = sigma1(W[r_m2]) + W[r_m7] + sigma0(W[r_m15]) + W[r_m16];
    end

    T1 = h + Sigma1(e) + Ch(e,f,g) + K[round] + Wt;
    T2 = Sigma0(a) + Maj(a,b,c);

    // next state
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
