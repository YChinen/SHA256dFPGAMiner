#include <verilated.h>
#include <cstdint>
#include <cstdio>
#include <random>

#include "Vminer_blockgen.h"

// Verilator wide vector helper:
// - 512-bit packed logic becomes VlWide<16> (16x32-bit words)
// - index 0 is LSB 32-bit, index 15 is MSB 32-bit
static inline void set_be_word512(WData* vec /*[16]*/, int w_index /*0..15 as W0..W15*/, uint32_t v) {
    vec[15 - w_index] = v; // W0 is MSW => index 15
}
static inline uint32_t get_be_word512(const WData* vec /*[16]*/, int w_index /*0..15 as W0..W15*/) {
    return vec[15 - w_index];
}

// tail_fixed is 96-bit: [95:64][63:32][31:0]
// In Verilator wide: index0=LSB(31:0), index1=63:32, index2=95:64
static inline void set_tail96(WData* tail /*[3]*/, uint32_t hi, uint32_t mid, uint32_t lo) {
    tail[0] = lo;
    tail[1] = mid;
    tail[2] = hi;
}
static inline void get_tail96(const WData* tail /*[3]*/, uint32_t& hi, uint32_t& mid, uint32_t& lo) {
    lo  = tail[0];
    mid = tail[1];
    hi  = tail[2];
}

static bool check_eq_u32(uint32_t got, uint32_t exp, const char* name, int idx) {
    if (got != exp) {
        std::fprintf(stderr, "%s mismatch idx=%d got=%08x exp=%08x\n", name, idx, got, exp);
        return false;
    }
    return true;
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    auto* dut = new Vminer_blockgen;

    std::mt19937 rng(1);
    std::uniform_int_distribution<uint32_t> dist(0, 0xffffffffu);

    // ---- Random tests
    for (int tc = 0; tc < 1000; tc++) {
        // Randomize inputs
        uint32_t b1_w[16];
        for (int i = 0; i < 16; i++) b1_w[i] = dist(rng);

        uint32_t t_hi = dist(rng);
        uint32_t t_mid = dist(rng);
        uint32_t t_lo = dist(rng);

        uint32_t nonce = dist(rng);

        // Drive block1_fixed (512-bit)
        for (int i = 0; i < 16; i++) set_be_word512(dut->block1_fixed, i, b1_w[i]);

        // Drive tail_fixed (96-bit) = [95:64]=hi, [63:32]=mid, [31:0]=lo
        set_tail96(dut->tail_fixed, t_hi, t_mid, t_lo);

        // Drive nonce
        dut->nonce = nonce;

        // Evaluate combinational
        dut->eval();

        // ---- Expected outputs
        // block1_o should match block1_fixed (word-by-word)
        for (int i = 0; i < 16; i++) {
            uint32_t got = get_be_word512(dut->block1_o, i);
            if (!check_eq_u32(got, b1_w[i], "block1_o", i)) return 1;
        }

        // block2_o expected mapping:
        // W0=tail[95:64], W1=tail[63:32], W2=tail[31:0], W3=nonce
        // W4=0x80000000, W5..W14=0, W15=0x00000280
        uint32_t exp_w[16] = {};
        exp_w[0]  = t_hi;
        exp_w[1]  = t_mid;
        exp_w[2]  = t_lo;
        exp_w[3]  = nonce;
        exp_w[4]  = 0x80000000u;
        for (int i = 5; i <= 14; i++) exp_w[i] = 0;
        exp_w[15] = 0x00000280u;

        for (int i = 0; i < 16; i++) {
            uint32_t got = get_be_word512(dut->block2_o, i);
            if (!check_eq_u32(got, exp_w[i], "block2_o", i)) return 1;
        }
    }

    delete dut;
    std::puts("PASS");
    return 0;
}
