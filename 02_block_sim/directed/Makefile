# Directed (non-UVM) block simulations.
# Each TEST is a VCS script under sim/<module>. RTL lives in 01_rtl/.
#
#   make TEST=sram
#   make vcs  TEST=mac
#   make sim  TEST=controller
#   make wave TEST=buffer
#   make TEST=ai_acc MODE=identity
#   make TEST=ai_acc MODE=all MATRIX_SIZE=32
#   make clean TEST=sram

SHELL := /bin/bash
SIM   := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

KNOWN := mac sram controller buffer ai_acc

ifeq ($(origin TEST),command line)
  .DEFAULT_GOAL := all
else
  .DEFAULT_GOAL := help
endif

ifeq ($(origin TEST),command line)
  ifeq ($(filter $(TEST),$(KNOWN)),)
    $(error Unknown TEST='$(TEST)'. Choices: $(KNOWN))
  endif
  PROJ := $(SIM)/sim/$(TEST)
endif

.PHONY: all vcs sim wave clean help $(KNOWN)

all: vcs sim

help:
	@echo "sim/<module>   modules: $(KNOWN)"
	@echo "  make vcs  TEST=<module>    compile against ../../01_rtl"
	@echo "  make sim  TEST=<module>    run"
	@echo "  make wave TEST=<module>    open the FSDB in Verdi"
	@echo "  make TEST=<module>         compile and run"
	@echo "  make clean TEST=<module>"
	@echo "buffer / ai_acc: MATRIX_SIZE=8|32  ARRAY_SIZE=8"
	@echo "ai_acc: MODE=identity|ones|all|0..9  SEED=1"

vcs sim wave clean:
	$(if $(PROJ),,$(error Set TEST, for example: make $@ TEST=sram))
	$(MAKE) -C $(PROJ) $@

$(KNOWN):
	$(MAKE) all TEST=$@
