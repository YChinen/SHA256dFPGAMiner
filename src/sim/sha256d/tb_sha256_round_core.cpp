// sim/tb_round.cpp
#include <cstdint>
#include <cstdio>
#include <deque>
#include <random>
#include <verilated.h>
#include <verilated_vcd_c.h>

#include "Vsha256_round_core.h"

static inline uint32_t rotr32(uint32_t x, int s) {
  return (x >> s) | (x << (32 - s));
}
static inline uint32_t Sigma0(uint32_t x) {
  return rotr32(x, 2) ^ rotr32(x, 13) ^ rotr32(x, 22);
}
static inline uint32_t Sigma1(uint32_t x) {
  return rotr32(x, 6) ^ rotr32(x, 11) ^ rotr32(x, 25);
}
static inline uint32_t Ch(uint32_t x, uint32_t y, uint32_t z) {
  return (x & y) ^ (~x & z);
}
static inline uint32_t Maj(uint32_t x, uint32_t y, uint32_t z) {
  return (x & y) ^ (x & z) ^ (y & z);
}

struct InVec {
  uint32_t a, b, c, d, e, f, g, h, k, w;
};
struct OutVec {
  uint32_t a, b, c, d, e, f, g, h;
};

static OutVec ref_round(const InVec &in) {
  uint32_t s0 = Sigma0(in.a);
  uint32_t s1 = Sigma1(in.e);
  uint32_t ch = Ch(in.e, in.f, in.g);
  uint32_t maj = Maj(in.a, in.b, in.c);

  // 参照は素直に足す（DUTはCSAで畳んでるが数学的に同じ）
  uint32_t T1 = in.h + s1 + ch + in.k + in.w;
  uint32_t T2 = s0 + maj;

  OutVec o{};
  o.a = T1 + T2;
  o.b = in.a;
  o.c = in.b;
  o.d = in.c;
  o.e = in.d + T1;
  o.f = in.e;
  o.g = in.f;
  o.h = in.g;
  return o;
}

static void tick(Vsha256_round_core *dut, VerilatedVcdC *tfp, vluint64_t &t) {
  dut->clk = 0;
  dut->eval();
  if (tfp)
    tfp->dump(t++);
  dut->clk = 1;
  dut->eval();
  if (tfp)
    tfp->dump(t++);
}

int main(int argc, char **argv) {
  Verilated::commandArgs(argc, argv);
  auto *dut = new Vsha256_round_core;

  bool trace = true;
  VerilatedVcdC *tfp = nullptr;
  if (trace) {
    Verilated::traceEverOn(true);
    tfp = new VerilatedVcdC;
    dut->trace(tfp, 99);
    tfp->open("round.vcd");
  }

  vluint64_t t = 0;

  // reset
  dut->rst_n = 0;
  dut->valid_i = 0;
  tick(dut, tfp, t);
  tick(dut, tfp, t);
  dut->rst_n = 1;
  tick(dut, tfp, t);

  std::mt19937 rng(1);
  std::uniform_int_distribution<uint32_t> dist(0, 0xFFFFFFFFu);

  // 2-stage pipeline なので、入力→出力まで2サイクル遅延（validも同様）
  std::deque<OutVec> exp_q;
  std::deque<int> v_q;

  const int N = 2000;

  for (int i = 0; i < N; i++) {
    InVec in{dist(rng), dist(rng), dist(rng), dist(rng), dist(rng),
             dist(rng), dist(rng), dist(rng), dist(rng), dist(rng)};
    int vin = 1; // 常にvalidで流す（気分で0混ぜても良い）

    // drive inputs
    dut->valid_i = vin;
    dut->a_i = in.a;
    dut->b_i = in.b;
    dut->c_i = in.c;
    dut->d_i = in.d;
    dut->e_i = in.e;
    dut->f_i = in.f;
    dut->g_i = in.g;
    dut->h_i = in.h;
    dut->k_i = in.k;
    dut->w_i = in.w;

    // enqueue expected
    v_q.push_back(vin);
    exp_q.push_back(ref_round(in));

    // tick
    tick(dut, tfp, t);

    // check output (2-cycle latency)
    if (v_q.size() >= 2) {
      int v_out_exp = v_q.front();
      v_q.pop_front();
      OutVec e = exp_q.front();
      exp_q.pop_front();

      if (dut->valid_o != (uint32_t)v_out_exp) {
        std::fprintf(stderr, "VALID mismatch at i=%d got=%u exp=%d\n", i,
                     (unsigned)dut->valid_o, v_out_exp);
        return 1;
      }
      if (v_out_exp) {
        auto neq = [&](uint32_t got, uint32_t exp, const char *name) {
          if (got != exp) {
            std::fprintf(stderr, "%s mismatch at i=%d got=%08x exp=%08x\n",
                         name, i, got, exp);
            return true;
          }
          return false;
        };
        bool bad = false;
        bad |= neq(dut->a_o, e.a, "a");
        bad |= neq(dut->b_o, e.b, "b");
        bad |= neq(dut->c_o, e.c, "c");
        bad |= neq(dut->d_o, e.d, "d");
        bad |= neq(dut->e_o, e.e, "e");
        bad |= neq(dut->f_o, e.f, "f");
        bad |= neq(dut->g_o, e.g, "g");
        bad |= neq(dut->h_o, e.h, "h");
        if (bad)
          return 1;
      }
    }
  }

  // drain a few cycles
  for (int i = 0; i < 5; i++) {
    dut->valid_i = 0;
    tick(dut, tfp, t);
  }

  if (tfp) {
    tfp->close();
    delete tfp;
  }
  delete dut;

  std::puts("PASS");
  return 0;
}
