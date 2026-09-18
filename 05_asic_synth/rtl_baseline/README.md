# Baseline RTL (no write-path register cloning)

Copy of [`01_rtl/`](../../01_rtl/). Unpacker `current_unpack_data` fans out combinationally onto inferred 256-deep flop-RAM `wr_data` ports. No per-bank or per-slice write registers.
