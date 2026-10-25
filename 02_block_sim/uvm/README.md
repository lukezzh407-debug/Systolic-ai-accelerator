# UVM bench for AI_ACC_TOP

```text
tb_top.sv
  clock, AI_ACC_TOP, uvm_config_db virtual apb_if, run_test()
        |
ai_acc_smoke_test / ai_acc_reg_test / ai_acc_matrix_mult_test
        |  extends
ai_acc_base_test     configure, write matrices, start, poll DONE, compare
        |
ai_acc_env
        |
apb_agent -- sequencer <-- apb_seq
          -- driver    --> apb_if --> DUT
```

`common/tb_params.svh` is the same register map as the directed bench (`ACT/WEI/OUT/CTRL/BIAS`). `common/ai_acc_sw_model.sv` is the same golden model.

```bash
./run_vcs.sh
./run_vcs.sh ai_acc_reg_test
./run_vcs.sh ai_acc_matrix_mult_test +MODE=2
./run_vcs.sh ai_acc_matrix_mult_test +MODE=all
```

A passing smoke transcript is in [`logs/smoke_run.txt`](logs/smoke_run.txt). `run_vcs.sh` writes `compile.log` and `run.log` locally; those are gitignored.
