# RTL file list. Override rtl_path before sourcing, e.g. from Makefile:
#   set rtl_path ../rtl_baseline
#   set rtl_path ../rtl_bank_registered
#   set rtl_path ../rtl_bank_internal_slice
if {![info exists rtl_path]} {
    set rtl_path "../rtl_baseline"
}

analyze -format sv \
    [list \
    "${rtl_path}/MAC.sv" \
    "${rtl_path}/wrappers_sram/sram.sv" \
    "${rtl_path}/wrappers_sram/DATA_UNPACKER.sv" \
    "${rtl_path}/wrappers_sram/BUFFER_WRAPPER_SR.sv" \
    "${rtl_path}/SA2APB_DATA_PROC.sv" \
    "${rtl_path}/SYSTOLIC_ARRAY.sv" \
    "${rtl_path}/SYSTOLIC_ARRAY_CONTROLLER.sv" \
    "${rtl_path}/AI_ACC_TOP.sv" \
    "${rtl_path}/subsystem.v" \
    ]
