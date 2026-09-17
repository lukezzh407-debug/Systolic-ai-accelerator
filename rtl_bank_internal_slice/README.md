# RTL: bank-internal slice version

Parallel copy of `rtl/`. **Do not replace `rtl/`.** Existing simulation / Fusion Compiler file lists (`analyze.tcl`, sim Makefiles) still point at `rtl/`.

## What changed

Only `wrappers_sram/BUFFER_WRAPPER_SR.sv` is functionally different.

Each 256-deep logical SRAM bank (`MATRIX_SIZE=32`, `ARRAY_SIZE=4`) is split into **4 physical slices of depth 64**. Write-data fanout becomes 1→4 (per-slice registers) then 1→64 (slice RAM), instead of 1→256. The extra write pipeline is still **one cycle** (slice-level `*_q`, not stacked on a bank-level stage).

`N_SLICE` must divide `BANK_DEPTH`.

## Tree (same as `rtl/`)

```
rtl_bank_internal_slice/
├── AI_ACC_TOP.sv
├── MAC.sv
├── SA2APB_DATA_PROC.sv
├── SYSTOLIC_ARRAY.sv
├── SYSTOLIC_ARRAY_CONTROLLER.sv
├── subsystem.v
└── wrappers_sram/
    ├── BUFFER_WRAPPER_SR.sv   ← intra-bank slicing
    ├── DATA_UNPACKER.sv
    └── sram.sv
```

To synthesize this tree, point `analyze.tcl`'s `rtl_path` at `../rtl_bank_internal_slice` in a **local** copy of the flow. Leave the repo `analyze.tcl` on `../rtl`.
