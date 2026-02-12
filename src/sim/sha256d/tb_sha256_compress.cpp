#include <verilated.h>
#include <verilated_vcd_c.h>

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <random>
#include <array>

#include "Vsha256_compress.h"

static inline uint32_t rotr32(uint32_t x, int s) {
    return (x >> s) | (x << (32 - s));
}
static inline uint32_t Ch(uint32_t x, uint32_t y, uint32_t z) {
    return (x & y) ^ (~x & z);
}
static inline uint32_t Maj(uint32_t x, uint32_t y, uint32_t z) {
    return (x & y) ^ (x & z) ^ (y & z);
}
static inline uint32_t Sigma0(uint32_t x) { return rotr32(x,2) ^ rotr32(x,13) ^ rotr32(x,22); }
static inline uint32_t Sigma1(uint32_t x) { return rotr32(x,6) ^ rotr32(x,11) ^ rotr32(x,25); }
static inline uint32_t sigma0(uint32_t x) { return rotr32(x,7) ^ rotr32(x,18) ^ (x >> 3); }
static inline uint32_t sigma1(uint32_t x) { return rotr32(x,17) ^ rotr32(x,19) ^ (x >> 10); }

// SHA-256 K constants
static constexpr uint32_t K[64] = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,
    0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,
    0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,
    0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,
    0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,
    0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,
    0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,
    0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,
    0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
};

// big-endian pack helpers
static inline uint32_t load_be32(const uint8_t* p) {
    return (uint32_t(p[0])<<24) | (uint32_t(p[1])<<16) | (uint32_t(p[2])<<8) | uint32_t(p[3]);
}
static inline void store_be32(uint8_t* p, uint32_t v) {
    p[0] = uint8_t(v>>24); p[1] = uint8_t(v>>16); p[2] = uint8_t(v>>8); p[3] = uint8_t(v);
}

static std::array<uint32_t,8> sha256_iv() {
    return { 0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
             0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19 };
}

// Reference compression: state_in (8 words) + block (64 bytes) -> state_out (8 words)
static std::array<uint32_t,8> ref_compress(const std::array<uint32_t,8>& st, const uint8_t block[64]) {
    uint32_t W[64];
    for (int i=0;i<16;i++) W[i] = load_be32(block + i*4);
    for (int i=16;i<64;i++) W[i] = sigma1(W[i-2]) + W[i-7] + sigma0(W[i-15]) + W[i-16];

    uint32_t a=st[0], b=st[1], c=st[2], d=st[3], e=st[4], f=st[5], g=st[6], h=st[7];

    for (int i=0;i<64;i++) {
        uint32_t T1 = h + Sigma1(e) + Ch(e,f,g) + K[i] + W[i];
        uint32_t T2 = Sigma0(a) + Maj(a,b,c);
        h = g;
        g = f;
        f = e;
        e = d + T1;
        d = c;
        c = b;
        b = a;
        a = T1 + T2;
    }

    std::array<uint32_t,8> out{
        a + st[0],
        b + st[1],
        c + st[2],
        d + st[3],
        e + st[4],
        f + st[5],
        g + st[6],
        h + st[7]
    };
    return out;
}

static void tick(Vsha256_compress* dut, VerilatedVcdC* tfp, vluint64_t& t) {
    dut->clk = 0; dut->eval(); if (tfp) tfp->dump(t++);
    dut->clk = 1; dut->eval(); if (tfp) tfp->dump(t++);
}

// Pack/unpack helpers for DUT ports
static void drive_state_i(Vsha256_compress* dut, const std::array<uint32_t,8>& st) {
    // state_i is 256-bit packed; Verilator exposes as WData (array) or vluint64_t depending on width.
    // Easiest: use the generated WData type via the public member: dut->state_i[0..7] as 32-bit chunks if defined.
    // Many times it becomes `VlWide<8>` in C++ with index 0 = least-significant 32 bits.
    // We'll write assuming little-chunk order: word0 -> lowest 32 bits.
    for (int i=0;i<8;i++) dut->state_i[i] = st[7 - i]; // adjust if your SV packs differently
}

static std::array<uint32_t,8> read_state_o(Vsha256_compress* dut) {
    std::array<uint32_t,8> st{};
    for (int i=0;i<8;i++) st[7 - i] = dut->state_o[i]; // adjust if your SV packs differently
    return st;
}

static void drive_block_i(Vsha256_compress* dut, const uint8_t block[64]) {
    // Similar packing caveat as state_i.
    // We'll pack 512-bit as 16 words big-endian in SV; many SV designs load W[i] from block_i[511 - 32*i -: 32]
    // That means block_i MSB holds W0.
    // In C++ wide vector, index 0 is LSB 32b. So we should map:
    // block_i word0 (LSB) = W15, block_i word15 (MSB) = W0
    for (int i=0;i<16;i++) {
        uint32_t w = load_be32(block + i*4);     // W[i]
        dut->block_i[15 - i] = w;                // reverse into little-chunk order
    }
}

static void print_state(const char* tag, const std::array<uint32_t,8>& st) {
    std::printf("%s: ", tag);
    for (int i=0;i<8;i++) std::printf("%08x%s", st[i], (i==7)?"\n":" ");
}

// Build padded single-block for message "abc"
static void make_abc_block(uint8_t block[64]) {
    std::memset(block, 0, 64);
    block[0] = 'a'; block[1] = 'b'; block[2] = 'c';
    block[3] = 0x80;
    // message length = 3 bytes = 24 bits, stored in last 8 bytes big-endian
    // For short messages, high 32 bits are 0
    block[63] = 24; // low byte of 64-bit length
}

// Known SHA-256("abc") = ba7816bf 8f01cfea 414140de 5dae2223 b00361a3 96177a9c b410ff61 f20015ad
static std::array<uint32_t,8> sha256_abc_expected() {
    return { 0xba7816bf,0x8f01cfea,0x414140de,0x5dae2223,
             0xb00361a3,0x96177a9c,0xb410ff61,0xf20015ad };
}

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    auto* dut = new Vsha256_compress;

    // trace on
    Verilated::traceEverOn(true);
    VerilatedVcdC* tfp = new VerilatedVcdC;
    dut->trace(tfp, 99);
    tfp->open("sha256_compress.vcd");

    vluint64_t t=0;

    // reset
    dut->rst_n = 0;
    dut->start = 0;
    tick(dut, tfp, t);
    tick(dut, tfp, t);
    dut->rst_n = 1;
    tick(dut, tfp, t);

    // ---- Test 1: "abc" ----
    uint8_t block[64];
    make_abc_block(block);

    auto iv = sha256_iv();
    auto exp = ref_compress(iv, block);
    auto exp_known = sha256_abc_expected();

    // sanity: reference should match known
    if (exp != exp_known) {
        std::fprintf(stderr, "Reference implementation mismatch for abc!\n");
        print_state("ref", exp);
        print_state("known", exp_known);
        return 1;
    }

    // drive inputs
    drive_state_i(dut, iv);
    drive_block_i(dut, block);

    // pulse start for 1 cycle
    dut->start = 1;
    tick(dut, tfp, t);
    dut->start = 0;

    // wait for done
    int guard = 1000;
    while (!dut->done && guard-- > 0) {
        tick(dut, tfp, t);
    }
    if (guard <= 0) {
        std::fprintf(stderr, "Timeout waiting for done\n");
        return 1;
    }

    auto got = read_state_o(dut);
    if (got != exp_known) {
        std::fprintf(stderr, "SHA256(abc) mismatch!\n");
        print_state("got ", got);
        print_state("exp ", exp_known);
        std::fprintf(stderr, "NOTE: If only the final round seems off, check round==63 state_o timing in RTL.\n");
        return 1;
    }
    std::puts("Test1 PASS (abc)");

    // ---- Test 2: random blocks (optional) ----
    std::mt19937 rng(1);
    std::uniform_int_distribution<uint32_t> dist(0, 0xffffffffu);

    for (int tc=0; tc<100; tc++) {
        uint8_t blk[64];
        for (int i=0;i<64;i+=4) {
            uint32_t v = dist(rng);
            store_be32(blk+i, v);
        }
        auto st_in = sha256_iv(); // fixed IV for convenience
        auto exp2 = ref_compress(st_in, blk);

        // start new job (wait idle if your RTL has busy)
        drive_state_i(dut, st_in);
        drive_block_i(dut, blk);

        dut->start = 1;
        tick(dut, tfp, t);
        dut->start = 0;

        int g2 = 1000;
        while (!dut->done && g2-- > 0) tick(dut, tfp, t);
        if (g2 <= 0) { std::fprintf(stderr, "Timeout tc=%d\n", tc); return 1; }

        auto got2 = read_state_o(dut);
        if (got2 != exp2) {
            std::fprintf(stderr, "Random test mismatch tc=%d\n", tc);
            print_state("got", got2);
            print_state("exp", exp2);
            return 1;
        }
    }
    std::puts("Test2 PASS (random)");

    tfp->close();
    delete tfp;
    delete dut;

    std::puts("PASS");
    return 0;
}
