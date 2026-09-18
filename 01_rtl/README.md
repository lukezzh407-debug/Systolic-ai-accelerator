# 01 — Frontend RTL

Baseline accelerator RTL used as the readable source tree (`ARRAY_SIZE=4`, `MATRIX_SIZE=32`).

SRAM is inferred flop RAM (no foundry SRAM macros). In `wrappers_sram/BUFFER_WRAPPER_SR.sv`, APB unpacker output `current_unpack_data` connects **combinationally** to every bank’s `wr_data`. That is the version that produces the large Fusion Compiler timing violations; see [`05_asic_synth/README.md`](../05_asic_synth/README.md).

Write-path experiments (register cloning / intra-bank slices) stay under `05_asic_synth/` and are **not** this tree.
