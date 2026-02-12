VERILATOR := verilator
OBJROOT   := build
VFLAGS    := -Wall --cc --exe --build -O3 -j 0 --trace

.PHONY: test clean test-round test-compress test-blockgen

test: test-round test-compress test-blockgen

# ----------------------------------------
# sha256_round_core
# ----------------------------------------
ROUND_TOP := sha256_round_core
ROUND_RTL := $(abspath src/rtl/sha256/sha256_round_core.sv)
ROUND_TB  := $(abspath src/sim/sha256/tb_sha256_round_core.cpp)
ROUND_DIR := $(OBJROOT)/obj_dir_round

test-round:
	@echo "==> Running round test"
	mkdir -p $(ROUND_DIR)
	$(VERILATOR) $(VFLAGS) -Mdir $(ROUND_DIR) \
	  --top-module $(ROUND_TOP) \
	  $(ROUND_RTL) $(ROUND_TB)
	$(ROUND_DIR)/V$(ROUND_TOP)

# ----------------------------------------
# sha256_compress
# ----------------------------------------
COMP_TOP := sha256_compress
COMP_RTL := $(abspath src/rtl/sha256/sha256_compress.sv)
COMP_TB  := $(abspath src/sim/sha256/tb_sha256_compress.cpp)
COMP_DIR := $(OBJROOT)/obj_dir_compress

test-compress:
	@echo "==> Running compress test"
	mkdir -p $(COMP_DIR)
	$(VERILATOR) $(VFLAGS) -Mdir $(COMP_DIR) \
	  --top-module $(COMP_TOP) \
	  $(COMP_RTL) $(COMP_TB)
	$(COMP_DIR)/V$(COMP_TOP)

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
