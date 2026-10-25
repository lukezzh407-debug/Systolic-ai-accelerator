# Directed block tests

Each testbench drives one module directly. There is no UVM and no SoC.

| Order | Command | Testbench | DUT in `01_rtl/` |
|------:|---------|-----------|------------------|
| 1 | `make TEST=sram` | `tb/tb_sram.sv` | `wrappers_sram/sram.sv` |
| 2 | `make TEST=mac` | `tb/tb_mac.sv` | `MAC.sv` |
| 3 | `make TEST=controller` | `tb/tb_controller.sv` | `SYSTOLIC_ARRAY_CONTROLLER.sv` |
| 4 | `make TEST=buffer` | `tb/tb_buffer_wrapper.sv` | `wrappers_sram/BUFFER_WRAPPER_SR.sv` |
| 5 | `make TEST=ai_acc` | `tb/tb_ai_acc_top.sv` | `AI_ACC_TOP.sv` |

`DATA_UNPACKER` and `SYSTOLIC_ARRAY` have no standalone testbench. The buffer test covers unpack widths, and the top test covers the array together with the controller.

Shared parameters and the golden GEMM model are in `common/`. Scripts under `sim/<module>/` pass `01_rtl` on the VCS command line; they do not copy it.

Passing transcripts: [`logs/`](logs/).
