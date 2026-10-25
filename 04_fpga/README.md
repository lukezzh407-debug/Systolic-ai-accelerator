# 04 — FPGA

Target is a PYNQ-Z1 (`xc7z020clg400-1`). The bitstream top is not `AI_ACC_TOP`. It is [`rtl/DidacticNavigator.v`](rtl/DidacticNavigator.v), a board wrapper around the Edu4Chip SoC.

```text
DidacticNavigator
  BSCANE2 (JTAG chain 4 / USER4)   on-chip JTAG, no package JTAG pins
  Didactic                         Edu4Chip SoC (Ibex + OBI + subsystem slot)
    -> AI_ACC_TOP                  01_rtl/, hooked up as in 03_soc_edu4chip/
```

`clk_in` goes straight into `Didactic`. The same file also defines a `Pll` (PLLE2); `DidacticNavigator` does not instantiate it. Reset, UART, SPI, and 16 GPIO pins are the SoC pins, constrained in [`constraints/navigator.xdc`](constraints/navigator.xdc). The clock constraint is 50 MHz on `clk_in` (pin `U18`).

`Didactic` itself stays in the Edu4Chip checkout. This directory only adds the wrapper, the pin constraints, and a short Vivado script.

## Run

Clone the SoC next to this repo, then from `04_fpga/`:

```bash
git clone https://github.com/Edu4Chip/Didactic-SoC.git "$HOME/Edu4Chip/Didactic-SoC"
export DIDACTIC_SRC=$HOME/Edu4Chip/Didactic-SoC
export RTL_PATH=$(pwd)/../01_rtl
export BUILD_DIR=$(pwd)/build
export PROJECT=z1
vivado -mode batch -source scripts/run_navigator.tcl
```

The upstream flow this is cut down from is [`fpga/scripts/run_xilinx.tcl`](https://github.com/Edu4Chip/Didactic-SoC/blob/main/fpga/scripts/run_xilinx.tcl), launched by [`fpga/Makefile`](https://github.com/Edu4Chip/Didactic-SoC/blob/main/fpga/Makefile) (`make all_xilinx`, `PROJECT=z1`). Their board top is [`DidacticZ1.v`](https://github.com/Edu4Chip/Didactic-SoC/blob/main/fpga/rtl/DidacticZ1.v); ours is `DidacticNavigator`.

After the bitstream, the bare-metal program is compiled in the Edu4Chip `fpga/sw` tree and loaded with OpenOCD. The program writes the accelerator at `0x0151_0000` (see `03_soc_edu4chip`). Bitstreams are not stored here.
