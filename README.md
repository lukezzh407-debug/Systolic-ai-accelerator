# Systolic Array AI Accelerator

APB-attached 4×4 systolic-array accelerator for 32×32 integer GEMM (`ARRAY_SIZE=4`, `MATRIX_SIZE=32`). Frontend RTL, SoC/FPGA bring-up, and an X-FAB **XH018** Fusion Compiler path. Intended as a public project log for internships / full-time applications.

**Current snapshot:** RTL + **logic synthesis to `logic_opto`**. Block sim, Edu4Chip SoC + C host, FPGA, gate-level sim, and PnR are directory placeholders.

## Results (synthesis, this snapshot)

| Item | Value |
|------|--------|
| Tool | Synopsys Fusion Compiler X-2025.06-SP3 |
| Process | X-FAB xh018 HD stdcells |
| Clock | 100 ns (10 MHz), SSG @ 1.62 V / −40 °C |
| SRAM | Inferred flop RAM (no foundry SRAM macros) |

**Baseline RTL** ([`01_rtl/`](01_rtl/)): unpacker output drives every inferred RAM D pin in the same cycle. STA sees ~1500 ns slew on `current_unpack_data` → `ram_reg[*]/D`, so **65536** paths miss the 100 ns clock (WNS ≈ **−1484 ns**). That is load on a combo net, not extra ALU logic. Reports: [`05_asic_synth/reports_baseline/`](05_asic_synth/reports_baseline/).

With per-bank (then per-slice) write registers, **path timing closes**; `logic_opto` still inserts **0 buffers**, so max-cap nets remain. Utilization ≫ 0.75 until macros or a larger floorplan.

| RTL | Violating paths | WNS | Max-cap nets | Notes |
|-----|-----------------|-----|--------------|--------|
| Baseline (no cloning) | 65536 | −1484 ns | 1176 | [`reports_baseline/`](05_asic_synth/reports_baseline/) |
| Per-bank write registers | 0 | +63.7 ns | 1412 | [`reports_bank_registered/`](05_asic_synth/reports_bank_registered/) |
| Intra-bank 4×64 slices | 0 | +63.5 ns | 3583 | Count ↑, worst net ↓. [`reports_bank_internal_slice/`](05_asic_synth/reports_bank_internal_slice/) |

## Repository layout

| Path | Status | Contents |
|------|--------|----------|
| [`01_rtl/`](01_rtl/) | Done | Baseline frontend RTL (no write-path cloning) |
| [`02_block_sim/`](02_block_sim/) | Later | Module testbenches |
| [`03_soc_edu4chip/`](03_soc_edu4chip/) | Later | APB SoC integration, C/C++ host |
| [`04_fpga/`](04_fpga/) | Later | Board bring-up (no vendor bitstream) |
| [`05_asic_synth/`](05_asic_synth/) | In progress | FC scripts, constraints, three RTL variants, QoR reports |
| [`06_gls/`](06_gls/) | Later | Gate-level sim notes (no netlist in git) |
| [`07_pnr_layout/`](07_pnr_layout/) | Later | PnR / layout screenshots (no GDS) |
| [`docs/`](docs/) | Done | Technical poster |

## What is not in git

X-FAB Liberty/LEF/NDM, Fusion Compiler `work/` libraries, mapped `*_netlist.v.gz`, license servers, and absolute PDK paths. Scripts expect `XFAB_HOME` on a licensed machine. See [`05_asic_synth/pdk/README.md`](05_asic_synth/pdk/README.md).

## License note

RTL and reports are for academic / evaluation reference. Foundry PDK and EDA licenses remain with the foundry and university.
