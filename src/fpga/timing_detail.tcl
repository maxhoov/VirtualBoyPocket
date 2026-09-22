project_open ap_core
create_timing_netlist -model slow
read_sdc
update_timing_netlist
report_timing -setup -npaths 20 -detail full_path -file output_files/critical_paths.rpt
report_ucp -file output_files/unconstrained_paths.rpt
delete_timing_netlist
project_close
