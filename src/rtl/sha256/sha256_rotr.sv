module sha256_rotr #(
    parameter SHIFT = 0
) (
    input   logic   [31:0]  x,
    output  logic   [31:0]  y
);
    always_comb begin : ROTR
        y = (x >> SHIFT) | (x << (32 - SHIFT));
    end
endmodule
