TOP      := sha256_round_core
RTL      := $(abspath src/rtl/sha256d/sha256_round_core.sv)
TB       := $(abspath src/sim/sha256d/tb_sha256_round_core.cpp)
OBJDIR   := build/obj_dir

VERILATOR := verilator

.PHONY: test clean

test:
	mkdir -p $(OBJDIR)
	$(VERILATOR) -Wall --cc --exe --build \
	  -O3 -j 0 \
	  --trace \
	  -Mdir $(OBJDIR) \
	  --top-module $(TOP) \
	  $(RTL) $(TB)
	$(OBJDIR)/V$(TOP)

clean:
	rm -rf build *.vcd
