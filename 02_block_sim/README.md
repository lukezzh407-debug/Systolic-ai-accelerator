# 02 — Block-level simulation

Testbenches and the scripts that compile them. The DUT is the RTL already in [`01_rtl/`](../01_rtl/). This directory does not contain RTL, `simv`, waveforms, or VCS work files.

| Directory | Contents |
|-----------|----------|
| [`directed/`](directed/) | Non-UVM testbench per block, plus a top-level directed GEMM |
| [`uvm/`](uvm/) | UVM 1.2 bench for `AI_ACC_TOP` (smoke, register, matrix multiply) |

Example run transcripts are in `directed/logs/` and `uvm/logs/`. They are text captures of passing VCS runs, with the tool banner and FSDB dump messages removed. The controller transcript is shortened: the full log prints one line per cycle out to `SA_done` at cycle 786.

Requires Synopsys VCS. Waveforms also require Verdi (`VERDI_HOME`). UVM uses the VCS-bundled UVM 1.2 library (`-ntb_opts uvm-1.2`).

## Directed

```bash
cd 02_block_sim/directed
make TEST=sram
make TEST=mac
make TEST=controller
make TEST=buffer                  # 8x8; 32x32: MATRIX_SIZE=32
make TEST=ai_acc                  # identity + ones + one random 8-bit case
make TEST=ai_acc MODE=2           # mode index 0..9
make TEST=ai_acc MODE=identity
```

`make vcs TEST=<name>` only compiles. `make sim` only runs. `make wave` opens the FSDB.

## UVM

```bash
cd 02_block_sim/uvm
./run_vcs.sh                                  # ai_acc_smoke_test
./run_vcs.sh ai_acc_reg_test
./run_vcs.sh ai_acc_matrix_mult_test +MODE=2
```

`tb_top` only generates the clock, instantiates `AI_ACC_TOP`, and calls `run_test()`. APB pins are driven by `apb_driver` through `apb_if`.
