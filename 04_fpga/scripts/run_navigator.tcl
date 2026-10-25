# Short PYNQ-Z1 flow. Top is DidacticNavigator, not AI_ACC_TOP.
# SoC RTL (Didactic, Ibex, OBI) comes from a checkout of
# https://github.com/Edu4Chip/Didactic-SoC  — it is not in this repository.
#
#   export DIDACTIC_SRC=$HOME/Edu4Chip/Didactic-SoC
#   export RTL_PATH=<this-repo>/01_rtl
#   export BUILD_DIR=<this-repo>/04_fpga/build
#   export PROJECT=z1
#   vivado -mode batch -source scripts/run_navigator.tcl

set PROJECT   $::env(PROJECT)
set BUILD_DIR $::env(BUILD_DIR)
set RTL_PATH  $::env(RTL_PATH)
set FPGA_PATH [file dirname [file dirname [info script]]]

if { $PROJECT ne "z1" } {
    puts "ERROR: this example only sets up PROJECT=z1 (xc7z020clg400-1)."
    exit 1
}

create_project ai_acc_z1 $BUILD_DIR/fpga/z1 -force -part xc7z020clg400-1

# Our accelerator. subsystem.v is the slot body; see 03_soc_edu4chip/.
set rtl_files [list \
    $RTL_PATH/MAC.sv \
    $RTL_PATH/wrappers_sram/sram.sv \
    $RTL_PATH/wrappers_sram/DATA_UNPACKER.sv \
    $RTL_PATH/wrappers_sram/BUFFER_WRAPPER_SR.sv \
    $RTL_PATH/SA2APB_DATA_PROC.sv \
    $RTL_PATH/SYSTOLIC_ARRAY.sv \
    $RTL_PATH/SYSTOLIC_ARRAY_CONTROLLER.sv \
    $RTL_PATH/AI_ACC_TOP.sv \
    $RTL_PATH/subsystem.v \
    $FPGA_PATH/rtl/DidacticNavigator.v \
]
add_files -norecurse $rtl_files
set_property file_type SystemVerilog [get_files -of_objects [current_fileset]]

# Didactic.v and the Ibex/OBI sources are added from the Edu4Chip checkout
# by its own fpga/scripts/run_xilinx.tcl. Point that script at this project
# or add those files here before synth_design.
puts "DIDACTIC_SRC=$::env(DIDACTIC_SRC)"
puts "Add the Edu4Chip SoC sources, then set the top and constraints below."

set_property top DidacticNavigator [current_fileset]
add_files -fileset constrs_1 -norecurse $FPGA_PATH/constraints/navigator.xdc
set_property verilog_define {SYNTHESIS=1 FPGA=1 PRIM_DEFAULT_IMPL=prim_pkg::ImplXilinx} [current_fileset]

# Uncomment after the SoC sources are in the project.
# launch_runs synth_1 -jobs 4
# wait_on_run synth_1
# launch_runs impl_1 -jobs 4 -to_step write_bitstream
# wait_on_run impl_1
