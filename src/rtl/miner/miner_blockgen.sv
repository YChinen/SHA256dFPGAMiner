module miner_blockgen (
    input   logic   [511:0] block1_fixed,
    input   logic   [95:0]  tail_fixed,
    input   logic   [31:0]  nonce,

    output  logic   [511:0] block1_o,
    output  logic   [511:0] block2_o
);
    always_comb begin : BTC_BLOCKGEN
        block1_o = block1_fixed;

        block2_o = '0;

        block2_o[511 - 0*32 -: 32] = tail_fixed[95:64];
        block2_o[511 - 1*32 -: 32] = tail_fixed[63:32];
        block2_o[511 - 2*32 -: 32] = tail_fixed[31:0];
        block2_o[511 - 3*32 -: 32] = nonce;

        block2_o[511 - 4*32 -: 32] = 32'h8000_0000;
        block2_o[511 - 15*32 -: 32] = 32'h0000_0280;
    end
endmodule
