module sha256_l_sigma0(
    input   logic   [31:0]  x,
    output  logic   [31:0]  y
);
    logic   [31:0]  tmp_2;
    logic   [31:0]  tmp_13;
    logic   [31:0]  tmp_22;

    sha256_rotr #(2) rotr_2 (.x(x), .y(tmp_2));
    sha256_rotr #(13) rotr_13 (.x(x), .y(tmp_13));
    sha256_rotr #(22) rotr_22 (.x(x), .y(tmp_22));

    always_comb begin : L_SIGMA0
        y = tmp_2 ^ tmp_13 ^ tmp_22;
    end
endmodule
