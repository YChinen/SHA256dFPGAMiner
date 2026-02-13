module sha256_s_sigma1(
    input   logic   [31:0]  x,
    output  logic   [31:0]  y
);
    logic   [31:0]  tmp_17;
    logic   [31:0]  tmp_19;

    sha256_rotr #(17) rotr_17 (.x(x), .y(tmp_17));
    sha256_rotr #(19) rotr_19 (.x(x), .y(tmp_19));

    always_comb begin : S_SIGMA1
        y = tmp_17 ^ tmp_19 ^ (x >> 10);
    end
endmodule
