module sha256_l_sigma1(
    input   logic   [31:0]  x,
    output  logic   [31:0]  y
);
    logic   [31:0]  tmp_6;
    logic   [31:0]  tmp_11;
    logic   [31:0]  tmp_25;

    sha256_rotr #(6) rotr_6 (.x(x), .y(tmp_6));
    sha256_rotr #(11) rotr_11 (.x(x), .y(tmp_11));
    sha256_rotr #(25) rotr_25 (.x(x), .y(tmp_25));

    always_comb begin : L_SIGMA1
        y = tmp_6 ^ tmp_11 ^ tmp_25;
    end
endmodule
