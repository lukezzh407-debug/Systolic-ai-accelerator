# 01 — Frontend RTL

Readable copy of the accelerator used in Fusion Compiler (`ARRAY_SIZE=4`, `MATRIX_SIZE=32`).

Write path in `wrappers_sram/BUFFER_WRAPPER_SR.sv` uses **per-bank** data/address/enable registers (one extra cycle vs. combinational unpacker → RAM).

The intra-bank 4×64 slice experiment lives only under [`05_asic_synth/rtl_bank_internal_slice/`](../05_asic_synth/rtl_bank_internal_slice/). Keep this tree for existing sim / SoC file lists.
