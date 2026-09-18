# 05 — ASIC synthesis (in progress)

Logic synthesis of `subsystem` with Synopsys Fusion Compiler, stopped at **`compile_fusion -to logic_opto`**. Gate-level sim, PnR, and layout are not done yet (`06_gls/`, `07_pnr_layout/`).

## Not in this folder

PDK / NDM / `work/` / mapped netlists. See [pdk/README.md](pdk/README.md).

## RTL variants

| Directory | What changed |
|-----------|----------------|
| `rtl_baseline/` | Original write path: combinational `current_unpack_data` → all inferred RAM `wr_data`. Same tree as [`01_rtl/`](../01_rtl/). |
| `rtl_bank_registered/` | Per-bank write-data/address/enable registers (Approach A). |
| `rtl_bank_internal_slice/` | Each 256-deep bank split into 4×64 slices; write registers at slice level (still +1 cycle). |

`ARRAY_SIZE=4`, `MATRIX_SIZE=32`. Without foundry SRAM macros, each “SRAM” is a 256×32 flop array.

## Why the baseline has huge timing violations

No SRAM compiler is available, so `simple_dualport_ram` infers **one flop per bit**. For `MATRIX_SIZE=32` and `ARRAY_SIZE=4`, each logical bank is 256 words × 32 bits.

In the baseline, the unpacker is combinational: `PWDATA` → `current_unpack_data` → **every** bank row’s D pin on the same net (`wr_data[k]`). One HD cell (`ON21HDX4` on `current_unpack_data[24]`) then sees on the order of **8 banks × 256 rows** loads. Transition time blows up (~1500 ns on a 100 ns clock), so STA reports:

- WNS ≈ **−1484 ns**
- **65536** violating paths in both `in2reg` and `clk_in` (APB `PWDATA` / unpacker flop → `ram_reg[*][*]/D`)
- max_trans and max_cap also violated (`logic_opto` inserts **0** buffers)

This is a **drive / fanout** problem, not an extra combinational algorithm. Per-bank (then per-slice) write registers cut that net so path timing closes; remaining max-cap nets are the still-unbuffered RAM internals.

## Published reports (xh018 HD, 100 ns, SSG 1.62 V / −40 °C)

| | Baseline (no cloning) | Bank registers | Intra-bank 4×64 |
|--|----------------------|----------------|-----------------|
| QoR | [`reports_baseline/`](reports_baseline/) | [`reports_bank_registered/`](reports_bank_registered/) | [`reports_bank_internal_slice/`](reports_bank_internal_slice/) |
| Path timing | **65536** paths, WNS ≈ **−1484 ns** | 0 violating paths, WNS ≈ +63.7 ns | 0 violating paths, WNS ≈ +63.5 ns |
| Max-cap **net count** | 1176 | 1412 | 3583 |
| Max-cap **severity** | 32640 | 1093 | 728 |
| Utilization | 2.40 | 2.41 | 2.49 |
| Buffers at `logic_opto` | 0 | 0 | 0 |

Slicing raises the **count** of max-cap nets (one illegal 256-load net → four illegal 64-load nets) while the **worst** net gets lighter. `set_max_capacitance 0.15` is still exceeded at 64 loads.

## How to re-run (licensed machine only)

```bash
source setup.sh
export XFAB_HOME=/path/to/xh018
# first time only: build gitignored NDM under pdk/stdlibs/
cd pdk/stdlibs && sh create.sh.example && cd ../..

make asic-all                               # baseline (01_rtl)
make asic-all VARIANT=bank_registered
make asic-all VARIANT=bank_internal_slice
```

Reports land in `reports_<variant>/`. `*.v.gz` netlists are gitignored.
