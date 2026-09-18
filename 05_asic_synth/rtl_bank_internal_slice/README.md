# Intra-bank slice RTL

Parallel copy of `01_rtl/`. **Do not replace `01_rtl/`.** Existing simulation / SoC file lists still point at the top-level frontend tree.

Only `wrappers_sram/BUFFER_WRAPPER_SR.sv` is functionally different: each 256-deep logical SRAM bank (`MATRIX_SIZE=32`, `ARRAY_SIZE=4`) is split into **4 physical slices of depth 64**. Write-data fanout becomes 1→4 (per-slice registers) then 1→64 (slice RAM). The extra write pipeline is still **one cycle**.

`N_SLICE` must divide `BANK_DEPTH`.
