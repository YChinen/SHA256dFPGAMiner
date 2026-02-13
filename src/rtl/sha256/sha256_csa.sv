module sha256_csa (
    input   logic   [31:0]  x,
    input   logic   [31:0]  y,
    input   logic   [31:0]  z,
    output  logic   [31:0]  csa_sum,
    output  logic   [31:0]  csa_car
);
    always_comb begin : SHA256_CSA
        csa_sum = x ^ y ^ z;
        csa_car = (x & y) | (x & z) | (y & z);
    end
endmodule
