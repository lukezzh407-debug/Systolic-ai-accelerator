# Intra-bank slice RTL

Does **not** replace [`01_rtl/`](../../01_rtl/). Only `wrappers_sram/BUFFER_WRAPPER_SR.sv` differs from baseline: each 256-deep logical SRAM bank is split into **4 physical slices of depth 64**, with write registers at slice level (still +1 cycle).

`N_SLICE` must divide `BANK_DEPTH`.
