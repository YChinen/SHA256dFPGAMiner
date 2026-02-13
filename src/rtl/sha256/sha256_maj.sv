module sha256_maj (
    input   logic   [31:0]  x,
    input   logic   [31:0]  y,
    input   logic   [31:0]  z,
    output  logic   [31:0]  maj
);
    always_comb begin : MAJ
        maj = (x & y) ^ (x & z) ^ (y & z);
    end
endmodule
