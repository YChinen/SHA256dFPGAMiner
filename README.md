# SHA256d FPGA Miner (Educational Sample)

This repository provides an educational reference implementation of SHA256 and SHA256d (Double SHA256) targeting FPGA platforms.

It is **not intended for commercial mining purposes**. The primary goals of this project are:

* Understanding the structure of the SHA256 compression function
* Studying integer addition and carry propagation behavior in FPGA architectures
* Learning pipelined design and parallelization strategies
* Practicing RTL verification using Verilator

---

## Features

* SystemVerilog implementation of a SHA256 round core
* Carry-Save Adder (CSA) based multi-operand addition optimization
* C++ reference testbench using Verilator
* Simple build structure suitable for CI integration (e.g., GitHub Actions)

By modifying the adder structure or pipeline depth, users can observe trade-offs between Fmax, resource usage, and throughput.

---

## Directory Structure

```
src/
  rtl/
    sha256d/
      sha256_round_core.sv

  sim/
    sha256d/
      tb_sha256_round_core.cpp

build/
```

* `rtl/` : RTL implementations
* `sim/` : C++ testbench for Verilator
* `build/` : Generated build artifacts (auto-generated)

---

## Build and Test

Requirements:

* Verilator
* g++ (C++17 compatible)
* make

Run the test:

```bash
make clean
make test
```

If successful, `PASS` will be printed and a waveform file (VCD) will be generated.

---

## Design Philosophy

### 1. Start with a Single SHA256 Round

The implementation begins with a single-round core. A C++ reference model is used to verify correctness before expanding to the full compression function.

### 2. Multi-Operand Addition Optimization

The SHA256 T1 computation consists of five operands:

```
T1 = h + Σ1(e) + Ch(e,f,g) + K[i] + W[i]
```

A naive serial addition causes long carry propagation chains, which often become the critical path on FPGA devices.

To mitigate this, intermediate results are combined using a Carry-Save Adder (CSA) tree, and only the final stage performs carry-propagation addition.

### 3. Educational-Oriented Implementation

* No reliance on DSP blocks
* Minimal dependence on synthesis-tool-specific optimizations
* Emphasis on readable and structurally clear logic

Performance optimization strongly depends on the target device and synthesis tool.
This repository serves as a clean starting point for experimentation.

---

## Future Work

* 64-round compression function implementation
* SHA256d (second SHA pass) integration
* Midstate support
* Parallel worker architecture
* Synthesis report comparison examples

---

## License

This project is intended as an educational reference implementation.
See the LICENSE file for details.

---

The goal of this project is to provide a solid and understandable reference implementation for studying FPGA-based hash circuit design.
