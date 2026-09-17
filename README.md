# Systolic Array AI Accelerator IP design

Public appendix materials for the Group 4 business / project plan.

## Contents

| Path | Description |
|------|-------------|
| `rtl/` | Baseline frontend RTL used in Fusion Compiler synthesis (`ARRAY_SIZE=4`). Keep this tree for existing sim / synth file lists. |
| `rtl_bank_internal_slice/` | Same RTL tree, but each 256-deep SRAM bank is sliced into 4×64 (`BUFFER_WRAPPER_SR.sv`). Does **not** replace `rtl/`. |
| `reports/` | Synopsys Fusion Compiler reports (timing / area / power / QoR), X-FAB **xh018**, clock **100 ns** |
| `docs/Group4_Poster.pdf` | Project technical poster |
| `synth_fc.tcl` | Synthesis flow script (library paths redacted; run against local PDK) |

## Key synthesis results (summary)

- **Tool:** Synopsys Fusion Compiler X-2025.06-SP3  
- **Process:** X-FAB xh018 (HD stdcells)  
- **Clock:** 100 ns (10 MHz), scenario SSG @ 1.62 V / −40 °C  
- **Timing:** WNS ≈ **+63.7 ns**, TNS = 0, **0** violating paths  
- **Area:** Total cell area ≈ **5.41×10⁶ µm²** (~5.41 mm² cell area; buffer/SRAM-as-flops dominate)  
- **Power (estimated activity):** Dynamic ≈ **1.20 mW**, Leakage ≈ **7.4 nW**  

> Proprietary PDK / NDM libraries and full gate-level netlists are **not** included in this public repository.

## License note

RTL and reports are provided for academic / evaluation reference. Third-party process IP remains with the foundry / university license holders.
