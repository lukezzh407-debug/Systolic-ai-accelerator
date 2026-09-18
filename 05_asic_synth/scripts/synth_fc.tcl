# Fusion Compiler synthesis (logic_opto). Requires a local X-FAB XH018 PDK.
# PDK, NDM, work library, and netlists are not in this repository.
#
# Optional Tcl variables (set from Makefile before this file is sourced):
#   rtl_path   default ../rtl_bank_internal_slice
#   rpt_dir    default ../reports_bank_internal_slice

set top_module subsystem
set clk_input clk
set output_name "${top_module}_100ns"

if {![info exists rtl_path]} {
    set rtl_path "../rtl_bank_internal_slice"
}
if {![info exists rpt_dir]} {
    set rpt_dir "../reports_bank_internal_slice"
}

set work_dir [pwd]
set lib_name "${top_module}.nlib"

set_host_options -max_cores 6

set reference_libs {}

# Local PDK hook — see ../pdk/README.md
source -echo ../pdk/tech.tcl

create_lib ${top_module} -scale_factor ${XFAB_DESIGN_LIBRARY_SCALE_FACTOR} -technology ${TECH_FILE} -ref_libs ${reference_libs}

source ../scripts/analyze.tcl
elaborate ${top_module}
set_top_module ${top_module}

file mkdir ${rpt_dir}
get_cells -hier -filter "(is_positive_level_sensitive==true||is_negative_level_sensitive==true)&&(is_rise_edge_triggered==false||is_fall_edge_triggered==false)" > "${rpt_dir}/${output_name}_latches.txt"

create_mode FuncModeB0
create_corner max.SSG.1P62V-0P00V-0P00V-0P00V.M40C_FuncCmaxDP
create_scenario -mode FuncModeB0 -corner max.SSG.1P62V-0P00V-0P00V-0P00V.M40C_FuncCmaxDP
source ../constraints/subsystem_0/top.tcl

# Units after top.tcl are ns / pF.
set_max_fanout 20 [current_design]
set_max_capacitance 0.15 [current_design]
set_max_transition 5.0 [current_design]
set_ideal_network [get_ports reset_n]

save_block -as ${top_module}/analyzed

set_app_options -name compile.flow.autoungroup -value false
compile_fusion -to logic_opto
save_block -as ${top_module}/compile_fusion
save_lib -all

report_user_units -nosplit  > "${rpt_dir}/${output_name}_units.txt"
report_clocks  -nosplit  > "${rpt_dir}/${output_name}_clocks.txt"
report_timing -nosplit -significant_digits 4 -max_paths 10 > "${rpt_dir}/${output_name}_timing.txt"
report_power  -nosplit  > "${rpt_dir}/${output_name}_power.txt"
report_area   -nosplit  > "${rpt_dir}/${output_name}_area.txt"
report_area   -nosplit -hierarchy > "${rpt_dir}/${output_name}_area_hierarchy.txt"
report_utilization -verbose > "${rpt_dir}/${output_name}_area_utilization.txt"
report_constraint -nosplit -verbose -significant_digits 4 > "${rpt_dir}/${output_name}_constraint.txt"
report_qor    -nosplit  > "${rpt_dir}/${output_name}_qor.txt"

# Netlists stay local (gitignored). Do not commit mapped stdcell Verilog.
write_verilog -compress gz "../${output_name}_netlist.v.gz"
ungroup -all -flatten
write_verilog -compress gz "../${output_name}_netlist_flat.v.gz"

puts "Synthesis complete. Reports in ${rpt_dir}"
quit
