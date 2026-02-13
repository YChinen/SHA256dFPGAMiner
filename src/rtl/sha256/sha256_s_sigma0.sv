module sha256_s_sigma0(
    input   logic   [31:0]  x,
    output  logic   [31:0]  y
);
    logic   [31:0]  tmp_7;
    logic   [31:0]  tmp_18;

    sha256_rotr #(7) rotr_7 (.x(x), .y(tmp_7));
    sha256_rotr #(18) rotr_18 (.x(x), .y(tmp_18));

    always_comb begin : S_SIGMA0
        y = tmp_7 ^ tmp_18 ^ (x >> 3);
    end
endmodule
