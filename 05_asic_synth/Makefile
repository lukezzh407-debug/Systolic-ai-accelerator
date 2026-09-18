# Fusion Compiler entry points. PDK is local-only (see pdk/README.md).
#
#   make asic-all                              # intra-bank slice RTL
#   make asic-all VARIANT=bank_registered      # per-bank write-register RTL

VARIANT ?= bank_internal_slice
RTL_DIR ?= ../rtl_$(VARIANT)
RPT_DIR ?= ../reports_$(VARIANT)

asic-prep:
	rm -rf work/* && mkdir -p work $(subst ../,,$(RPT_DIR))

asic-all: asic-prep
	cd work && fc_shell -x "set rtl_path $(RTL_DIR); set rpt_dir $(RPT_DIR)" \
		-file ../scripts/synth_fc.tcl -output_log_file ../synth_fc.log
