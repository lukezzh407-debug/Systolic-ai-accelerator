# Per-bank write-register RTL (Approach A)

Same modules as baseline, except `BUFFER_WRAPPER_SR.sv` clones write data/address/enable into **per-bank** registers (one extra cycle). Does not replace [`01_rtl/`](../../01_rtl/).
