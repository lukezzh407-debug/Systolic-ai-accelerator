# Systolic Array AI Accelerator

APB-attached 4×4 systolic-array accelerator for 32×32 integer GEMM (`ARRAY_SIZE=4`, `MATRIX_SIZE=32`). Frontend RTL, SoC/FPGA bring-up, and an X-FAB **XH018** Fusion Compiler path. Intended as a public project log for internships / full-time applications.

**Current snapshot:** RTL + **logic synthesis to `logic_opto`**. Block sim, Edu4Chip SoC + C host, FPGA, gate-level sim, and PnR are directory placeholders.

## Results (synthesis, this snapshot)

| Item | Value |
|------|--------|
| Tool | Synopsys Fusion Compiler X-2025.06-SP3 |
| Process | X-FAB xh018 HD stdcells |
| Clock | 100 ns (10 MHz), SSG @ 1.62 V / −40 °C |
| Path timing | WNS ≈ **+63.7 ns**, TNS = 0, **0** violating paths |
| Cell area | ≈ **5.41 mm²** (inferred flop SRAM dominates) |
| Power (tool estimate) | Dynamic ≈ 1.20 mW, leakage ≈ 7.4 nW |

Two SRAM write-path experiments (same clock, same floorplan budget):

| RTL | Max-cap **nets** | Max-cap **severity** | Notes |
|-----|------------------|----------------------|--------|
| Per-bank write registers | 1412 | 1093 | [`05_asic_synth/reports_bank_registered/`](05_asic_synth/reports_bank_registered/) |
| Intra-bank 4×64 slices | 3583 | 728 | Count ↑ (one fat net → four still-illegal nets); worst net ↓. [`reports_bank_internal_slice/`](05_asic_synth/reports_bank_internal_slice/) |

`logic_opto` inserts **0 buffers**. Utilization ≫ 0.75 until SRAM macros or a larger floorplan.

## Repository layout

| Path | Status | Contents |
|------|--------|----------|
| [`01_rtl/`](01_rtl/) | Done | Frontend RTL (per-bank write registers) |
| [`02_block_sim/`](02_block_sim/) | Later | Module testbenches |
| [`03_soc_edu4chip/`](03_soc_edu4chip/) | Later | APB SoC integration, C/C++ host |
| [`04_fpga/`](04_fpga/) | Later | Board bring-up (no vendor bitstream) |
| [`05_asic_synth/`](05_asic_synth/) | In progress | FC scripts, constraints, two RTL variants, QoR reports |
| [`06_gls/`](06_gls/) | Later | Gate-level sim notes (no netlist in git) |
| [`07_pnr_layout/`](07_pnr_layout/) | Later | PnR / layout screenshots (no GDS) |
| [`docs/`](docs/) | Done | Technical poster |

## What is not in git

X-FAB Liberty/LEF/NDM, Fusion Compiler `work/` libraries, mapped `*_netlist.v.gz`, license servers, and absolute PDK paths. Scripts expect `XFAB_HOME` on a licensed machine. See [`05_asic_synth/pdk/README.md`](05_asic_synth/pdk/README.md).

## License note

RTL and reports are for academic / evaluation reference. Foundry PDK and EDA licenses remain with the foundry and university.
