# VCS + Verdi script. RTL is ../../../../01_rtl (not copied here).
#   make vcs
#   make sim
#   make wave
#   make
#   make clean

SHELL := /bin/bash
tb_name ?= simv

NOVAS      ?= $(VERDI_HOME)/share/PLI/VCS/LINUX64
novas_args ?= -P $(NOVAS)/novas.tab $(NOVAS)/pli.a

VCS = vcs -full64 -sverilog -timescale=1ns/1ps \
          -kdb -lca -debug_access+all \
          +vcs+lic+wait \
          +define+FSDB \
          $(novas_args) \
          -top tb_mac \
          -o $(tb_name)

.PHONY: all vcs sim wave clean

all: vcs sim

vcs:
	mkdir -p wave
	$(VCS) -F ./filelist.f -l compile.log

sim:
	mkdir -p wave
	./$(tb_name) +DUMP_FSDB -l run.log

wave:
	@test -f ./wave/tb_mac.fsdb || { echo "missing wave/tb_mac.fsdb; run: make sim"; exit 1; }
	verdi -nologo -sv -F ./filelist.f -ssf ./wave/tb_mac.fsdb &

clean:
	rm -rf ./csrc *.daidir *.log *.vpd *.vdb simv* *.key *race.out*
	rm -rf *.args vc_hdrs.h
	rm -rf novas.conf novas.rc .vlogansetup.args verdiLog
	rm -rf AN.DB DVEfiles wave
