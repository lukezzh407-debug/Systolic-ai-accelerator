# Copy to tech.tcl is not required if XFAB_HOME is set — this file is the
# redacted hook used by scripts/synth_fc.tcl. Liberty / LEF / NDM are local.

if {![info exists env(XFAB_HOME)]} {
    error "Set environment variable XFAB_HOME to your local XH018 PDK root (files not in git)"
}

set XFAB_HOME $env(XFAB_HOME)

set TECH_FILE "${XFAB_HOME}/synopsys/v10_1/techMW/v10_1_1/xh018_xx51_HD_MET5_METMID.tf"
set TULP      "${XFAB_HOME}/synopsys/v10_1/TLUplus/v10_1_1/xh018_xx51_MET5_METMID_typ.tlu"
set LAYER_MAP "${XFAB_HOME}/synopsys/v10_1/TLUplus/v10_1_1/xh018_xx51_MET5_METMID.map"

lappend reference_libs ../pdk/stdlibs/xh018_HD.ndm

set XFAB_TECH_INFO " \
  {MET1 horizontal 0.0} \
  {MET3 horizontal 0.0} \
  {MET5 horizontal 0.0} \
  {POLY1 horizontal 0.0} \
  {MET2 vertical 0.0} \
  {MET4 vertical 0.0} \
  {METTP vertical 0.0} "

set SITE_DEFAULT "hd"
set XFAB_DESIGN_LIBRARY_SCALE_FACTOR "10000"
set DRV_CELL "INHDX1"
