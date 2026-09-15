# Name of the top module in your design
set top_module subsystem
set clk_input clk

# No need to change anything else below this line
set work_dir [pwd]
set lib_name "${top_module}.nlib"
set output_name "${top_module}_100ns"

# Other options
set_host_options -max_cores 6

# Specify libraries
set reference_libs {}

# load tech data, including std cell libs
source -echo ../xh018/tech.tcl

create_lib ${top_module} -scale_factor ${XFAB_DESIGN_LIBRARY_SCALE_FACTOR} -technology ${TECH_FILE} -ref_libs ${reference_libs}

# Read design files
source ../analyze.tcl
elaborate ${top_module}
set_top_module ${top_module}

# Searches for latches, which should be avoided. 
# Latches are typically created if you do not have a default assignment in combinational logic
get_cells -hier -filter "(is_positive_level_sensitive==true||is_negative_level_sensitive==true)&&(is_rise_edge_triggered==false||is_fall_edge_triggered==false)" > "../reports/${output_name}_latches.txt"

# define corner, read timing from block specifications
create_mode FuncModeB0
create_corner max.SSG.1P62V-0P00V-0P00V-0P00V.M40C_FuncCmaxDP
create_scenario -mode FuncModeB0 -corner max.SSG.1P62V-0P00V-0P00V-0P00V.M40C_FuncCmaxDP
source ../constraints/subsystem_0/top.tcl

# Design-level DRC constraints. The budget files only constrain the boundary
# ports, so without these the tool leaves internal high-fanout nets unbuffered.
# Units here are ns / pF: the mode file switches to ps at its first line and
# back to ns at its last line, so everything after top.tcl is in ns / pF.
# INHDX1 input pin load is 0.004738 pF, so 20 loads is roughly 0.095 pF.
set_max_fanout 20 [current_design]
set_max_capacitance 0.15 [current_design]
set_max_transition 5.0 [current_design]

# The reset tree is built during CTS in the backend, not here. Without this,
# the INHDX1 driving cell on reset_n has to drive 3339 RN pins directly, which
# yields a ~5839 ns transition time and pushes the recovery arc far outside its
# characterized range, producing 3355 bogus violations at -10604 ns.
set_ideal_network [get_ports reset_n]

save_block -as ${top_module}/analyzed

# Synthesize and optimize the design
set_app_options -name compile.flow.autoungroup -value false
compile_fusion -to logic_opto
# later remove "-to logic_opto" to run with initial placement
# but takes much more time
save_block -as ${top_module}/compile_fusion
save_lib -all

# Write out reports
report_user_units -nosplit  > "../reports/${output_name}_units.txt"
report_clocks  -nosplit  > "../reports/${output_name}_clocks.txt"
report_timing -nosplit -significant_digits 4 -max_paths 10 > "../reports/${output_name}_timing.txt"
report_power  -nosplit  > "../reports/${output_name}_power.txt"
report_area   -nosplit  > "../reports/${output_name}_area.txt"
report_area   -nosplit -hierarchy > "../reports/${output_name}_area_hierarchy.txt"
report_utilization -verbose > "../reports/${output_name}_area_utilization.txt"
report_constraint -nosplit -verbose -significant_digits 4 > "../reports/${output_name}_constraint.txt"
report_qor    -nosplit  > "../reports/${output_name}_qor.txt"

# Write out gate-level netlist
write_verilog -compress gz "../${output_name}_netlist.v.gz"
ungroup -all -flatten
write_verilog -compress gz "../${output_name}_netlist_flat.v.gz"

puts "The script has completed. You should see the reports and netlists."
quit
