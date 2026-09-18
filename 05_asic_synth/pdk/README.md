# Local PDK (not in git)

This folder only holds **hooks** so the Fusion Compiler scripts can find a licensed X-FAB XH018 install.

## What is not here

- Liberty (`.db` / `.lib`)
- LEF
- Compiled `xh018_HD.ndm`
- TLUplus / tech files
- Standard-cell simulation models

Those files stay on the university or foundry-licensed disk.

## What you need locally

1. Export `XFAB_HOME` to your XH018 PDK root.
2. One-time: copy `stdlibs/prep_ndm.tcl.example` to `stdlibs/prep_ndm.tcl`, run `create.sh.example` (needs `lm_shell`) to build `stdlibs/xh018_HD.ndm`. The NDM is gitignored.
3. `tech.tcl` already sources `$XFAB_HOME` and that NDM path.

`tech_xh018.sv` is a thin wrapper around HD cell names used by the SoC integration, not a copy of the library.
