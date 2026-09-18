########################################################################
#
# Budget for design subsystem_0
#
# Created by fc write_budgets on Thu May 21 12:58:03 2026

########################################################################
set extName "tcl"
set mode_names [list FuncModeB0]
set corner_names [list max.SSG.1P62V-0P00V-0P00V-0P00V.M40C_FuncCmaxDP]
set dir_name [file dirname [file normalize [info script]]]

set orig_mode [current_mode]
foreach_in_collection mode [get_modes] {
    set mode_name [get_attribute $mode name]
    set file_name ${dir_name}/mode_${mode_name}.${extName}
    if {[file readable $file_name]} {
	current_mode $mode
	puts "Reading block interface information for mode '$mode_name'."
	source $file_name
    }
}

set orig_corner [current_corner]
foreach_in_collection corner [get_corners] {
    set corner_name [get_attribute $corner name]
    if {$corner_name == "vipo_corner" || $corner_name == "estimated_corner"} continue
    set file_name ${dir_name}/corner_${corner_name}.${extName}
    if {[file readable $file_name]} {
	current_corner $corner
	puts "Reading block interface information for corner '$corner_name'."
	source $file_name
    }
}

# Print warning messages
puts ""
foreach_in_collection mode [get_modes] {
    set mode_name [get_attribute $mode name]
    set file_name ${dir_name}/mode_${mode_name}.${extName}
    if {![file readable $file_name]} {
	puts "Warning: No block interface information is available for mode '$mode_name' in '$dir_name'. (ABS-238)"
    }
}
foreach mode_name $mode_names {
    if {[get_modes $mode_name -quiet] == ""} {
	puts "Warning: Budget information could not be applied for mode '$mode_name'. (ABS-239)"
    } else {
	current_mode $mode_name
	if {[sizeof_collection [get_clocks -quiet -filter "is_virtual==false"]] == 0} {
	    puts "Warning: No clocks defined for mode '$mode_name'.  Block constraints should be loaded prior to applying block interface. (ABS-255)"
	}
    }
}
foreach_in_collection corner [get_corners] {
    set corner_name [get_attribute $corner name]
    if {$corner_name == "vipo_corner" || $corner_name == "estimated_corner"} continue
    set file_name ${dir_name}/corner_${corner_name}.${extName}
    if {![file readable $file_name]} {
	puts "Warning: No block interface information is available for corner '$corner_name'. (ABS-238)"
    }
}
foreach corner_name $corner_names {
    if {[get_corners $corner_name -quiet] == ""} {
	puts "Warning: Block interface information could not be applied for corner '$corner_name'. (ABS-239)"
    }
}
current_mode $orig_mode
current_corner $orig_corner

# init physical design
initialize_floorplan -shape R -side_length {1500 1500} -flip_first_row false -coincident_boundary true -site_def $SITE_DEFAULT
read_parasitic_tech -tlup ${TULP} -layermap ${LAYER_MAP} -name parasitics
set_parasitic_parameters -corners max.SSG.1P62V-0P00V-0P00V-0P00V.M40C_FuncCmaxDP -late_spec parasitics -early_spec parasitics -late_temperature -40 -early_temperature -40
set_attribute [get_site_defs] is_default false
set_attribute [get_site_defs $SITE_DEFAULT] is_default true
