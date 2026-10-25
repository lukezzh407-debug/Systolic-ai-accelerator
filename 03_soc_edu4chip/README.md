# 03 — Edu4Chip SoC integration

The accelerator is not a new bus. It sits in one student-subsystem slot of the [Edu4Chip Didactic SoC](https://github.com/Edu4Chip/Didactic-SoC): an Ibex core, an OBI interconnect, and APB peripherals. The slot already has clock, reset, IRQ, and PMOD. We only replace the empty subsystem with `AI_ACC_TOP`.

```text
Ibex
  -> OBI interconnect
    -> student wrapper (clock gate, IRQ mask, APB)
      -> subsystem / tum_ss
        -> AI_ACC_TOP          (this repo, 01_rtl/)
```

Software sees the slot at `0x0151_0000`. The wrapper strips the upper address bits, so the accelerator's `PADDR` is the 16-bit offset:

| Offset | Register |
|--------|----------|
| `0x0000` | activation matrix |
| `0x0004` | weight matrix |
| `0x0008` | output matrix |
| `0x000C` | control / status (`[0]` start, `[11]` done) |
| `0x0010` | bias |

## Two wrappers, one slot

The public Edu4Chip tree and the course tree name that slot differently.

- Public repo: [`tum_wrapper_0.v`](https://github.com/Edu4Chip/Didactic-SoC/blob/main/src/generated/tum_wrapper_0.v) instantiates a module called `tum_ss`. [`rtl/tum_ss.sv`](rtl/tum_ss.sv) is that module. It ties PMOD and IRQ off and connects the APB port to `AI_ACC_TOP`. Its port names (`clk_in`, `ss_ctrl_3`, `pmod_0_*`) match that upstream wrapper.
- Course tree: the same idea is module `subsystem`, already in this repo at [`01_rtl/subsystem.v`](../01_rtl/subsystem.v). Ports are the narrowed ones (`clk`, `reset_n`, 16-bit `PADDR`, one `pmod_*` bus). `student_wrapper_0` is the wrapper that instantiates `subsystem`.

[`rtl/ai_acc_dut.f`](rtl/ai_acc_dut.f) is the file list compiled into the slot. `RTL_PATH` points at [`01_rtl/`](../01_rtl/).

The rest of the SoC is not copied here.

## Upstream sources we build on

- Repository: https://github.com/Edu4Chip/Didactic-SoC
- Chip top: https://github.com/Edu4Chip/Didactic-SoC/blob/main/src/generated/Didactic.v
- TUM slot wrapper: https://github.com/Edu4Chip/Didactic-SoC/blob/main/src/generated/tum_wrapper_0.v
- FPGA flow used as the base: https://github.com/Edu4Chip/Didactic-SoC/blob/main/fpga/Makefile and https://github.com/Edu4Chip/Didactic-SoC/blob/main/fpga/scripts/run_xilinx.tcl
