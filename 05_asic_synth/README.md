# 05 — ASIC synthesis (in progress)

Logic synthesis of `subsystem` with Synopsys Fusion Compiler, stopped at **`compile_fusion -to logic_opto`**. Gate-level sim, PnR, and layout are not done yet (`06_gls/`, `07_pnr_layout/`).

## Not in this folder

PDK / NDM / `work/` / mapped netlists. See [pdk/README.md](pdk/README.md).

## RTL variants

| Directory | What changed |
|-----------|----------------|
| `rtl_bank_registered/` | Per-bank write-data/address/enable registers (Approach A). Same tree as [`01_rtl/`](../01_rtl/). |
| `rtl_bank_internal_slice/` | Each 256-deep bank split into 4×64 slices; write registers moved to slice level (still +1 cycle). |

`ARRAY_SIZE=4`, `MATRIX_SIZE=32`. Simulation / SoC file lists should keep using `01_rtl/` unless you explicitly switch.

## Published reports (xh018 HD, 100 ns, SSG 1.62 V / −40 °C)

| | Bank registers | Intra-bank 4×64 |
|--|----------------|-----------------|
| QoR | [`reports_bank_registered/`](reports_bank_registered/) | [`reports_bank_internal_slice/`](reports_bank_internal_slice/) |
| Path timing | 0 violating paths, WNS ≈ +63.7 ns | 0 violating paths, WNS ≈ +63.5 ns |
| Max-cap **net count** | 1412 | 3583 |
| Max-cap **severity** (constraint value) | 1093 | 728 |
| Utilization (floorplan vs cell area) | 2.41 | 2.49 |
| Buffers inserted at `logic_opto` | 0 | 0 |

The max-cap **count** rises after slicing because one illegal 256-load net becomes four illegal 64-load nets (64 pin-caps still exceed `set_max_capacitance 0.15`). Worst-net capacitance goes down. This stage does not insert buffers.

## How to re-run (licensed machine only)

```bash
# site-specific: Fusion Compiler module + XFAB_HOME
source setup.sh
export XFAB_HOME=/path/to/xh018
# first time only: build gitignored NDM under pdk/stdlibs/
cd pdk/stdlibs && sh create.sh.example && cd ../..

make asic-all                               # slice RTL
make asic-all VARIANT=bank_registered       # bank-register RTL
```

Reports land in `reports_<variant>/`. `*.v.gz` netlists are written next to the Makefile and are gitignored.
