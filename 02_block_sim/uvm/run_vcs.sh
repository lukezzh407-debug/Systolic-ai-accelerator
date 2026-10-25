#!/usr/bin/env bash
# Compile and run the UVM bench against ../../01_rtl.
#   ./run_vcs.sh
#   ./run_vcs.sh ai_acc_reg_test
#   ./run_vcs.sh ai_acc_matrix_mult_test +MODE=2
set -euo pipefail
cd "$(dirname "$0")"
TEST="${1:-ai_acc_smoke_test}"
if [[ $# -gt 0 ]]; then
  shift
fi
vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
    -f filelist.f -top tb_top -o simv -l compile.log
./simv +UVM_TESTNAME="$TEST" +UVM_NO_RELNOTES "$@" -l run.log
