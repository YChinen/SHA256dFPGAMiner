VERILATOR := verilator
OBJROOT   := build
VFLAGS    := -Wall --cc --exe --build -O3 -j 0 --trace

.PHONY: test clean test-sha256-round-core test-sha256-compress-core test-blockgen

test: test-sha256-round-core test-sha256-compress-core test-blockgen

# ----------------------------------------
# sha256_round_core
# ----------------------------------------
ROUND_CORE_TOP  := sha256_round_core
ROUND_CORE_SRCS := $(wildcard src/rtl/sha256/sha256_*.sv)
ROUND_CORE_TB   := $(abspath src/sim/sha256/tb_sha256_round_core.cpp)
ROUND_CORE_DIR  := $(OBJROOT)/obj_dir_round

test-sha256-round-core:
	@echo "==> Running SHA256 Round Core test"
	mkdir -p $(ROUND_CORE_DIR)
	$(VERILATOR) $(VFLAGS) -Mdir $(ROUND_CORE_DIR) \
	  --top-module $(ROUND_CORE_TOP) \
	  $(ROUND_CORE_SRCS) $(ROUND_CORE_TB)
	$(ROUND_CORE_DIR)/V$(ROUND_CORE_TOP)

# ----------------------------------------
# sha256_compress_core
# ----------------------------------------
COMPRESS_CORE_TOP  := sha256_compress_core
COMPRESS_CORE_SRCS := $(wildcard src/rtl/sha256/sha256_*.sv)
COMPRESS_CORE_TB   := $(abspath src/sim/sha256/tb_sha256_compress_core.cpp)
COMPRESS_CORE_DIR  := $(OBJROOT)/obj_dir_round

test-sha256-compress-core:
	@echo "==> Running SHA256 Compress Core test"
	mkdir -p $(COMPRESS_CORE_DIR)
	$(VERILATOR) $(VFLAGS) -Mdir $(COMPRESS_CORE_DIR) \
	  --top-module $(COMPRESS_CORE_TOP) \
	  $(COMPRESS_CORE_SRCS) $(COMPRESS_CORE_TB)
	$(COMPRESS_CORE_DIR)/V$(COMPRESS_CORE_TOP)

# ----------------------------------------
# miner_blockgen
# ----------------------------------------
BLOCKGEN_TOP := miner_blockgen
BLOCKGEN_RTL := $(abspath src/rtl/miner/miner_blockgen.sv)
BLOCKGEN_TB  := $(abspath src/sim/miner/tb_miner_blockgen.cpp)
BLOCKGEN_DIR := $(OBJROOT)/obj_dir_blockgen

test-blockgen:
	@echo "==> Running blockgen test"
	mkdir -p $(BLOCKGEN_DIR)
	$(VERILATOR) $(VFLAGS) -Mdir $(BLOCKGEN_DIR) \
	  --top-module $(BLOCKGEN_TOP) \
	  $(BLOCKGEN_RTL) $(BLOCKGEN_TB)
	$(BLOCKGEN_DIR)/V$(BLOCKGEN_TOP)

clean:
	rm -rf $(OBJROOT) *.vcd *.fst
