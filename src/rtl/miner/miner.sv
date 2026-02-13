module miner (
    input   logic           clk,
    input   logic           rst_n,

    input   logic           valid_i,
    input   logic   [607:0] data,

    output  logic           valid_o,
    output  logic           busy,
    output  logic   [31:0]  nonce
);

    // ------------------------------------------------------------
    // Internal signals
    // ------------------------------------------------------------
    logic           vl;
    logic           bsy;
    logic   [31:0]  nc;

    logic   [511:0] block1, block2;
    logic   [511:0] tmp_block1, tmp_block2;

    // ------------------------------------------------------------
    // Block generator
    // ------------------------------------------------------------
    miner_blockgen u_blockgen (
        .block1_fixed (data[511:0]),
        .tail_fixed   (data[607:512]),
        .block1_o     (tmp_block1),
        .block2_o     (tmp_block2)
    );

    // ------------------------------------------------------------
    // Stage registers
    // ------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            vl      <= 1'b0;
            bsy     <= 1'b0;
            nc      <= 32'd0;

            block1  <= '0;
            block2  <= '0;
        end
        else begin
            vl      <= valid_i;

            if (valid_i) begin
                block1  <= tmp_block1;
                block2  <= tmp_block2;
                bsy     <= 1'b1;
            end

            // TODO:
            // ここに nonce increment や stage制御を書く
        end
    end

    // ------------------------------------------------------------
    // Output assignment
    // ------------------------------------------------------------
    assign valid_o = vl;
    assign busy    = bsy;
    assign nonce   = nc;

endmodule
