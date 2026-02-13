module sha256_ch (
    input   logic   [31:0]  x,
    input   logic   [31:0]  y,
    input   logic   [31:0]  z,
    output  logic   [31:0]  ch
);
    always_comb begin : CH
        ch = (x & y) ^ (~x & z);
    end
endmodule
