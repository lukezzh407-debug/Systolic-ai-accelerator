# Paul R. Genssler <paul.genssler@tum.de>

##############
#   Synth    #
##############

asic-prep: 
	rm -rf work/* && mkdir -p work
	mkdir -p reports

asic-all: asic-prep
	cd work && fc_shell -file ../synth_fc.tcl -output_log_file ../synth_fc.log
