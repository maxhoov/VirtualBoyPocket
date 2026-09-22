onerror {quit -code 1}
vlib work
set questa_root [file dirname [file dirname [info nameofexecutable]]]
vmap altera_mf [file join $questa_root intel verilog altera_mf]
file mkdir apf
file copy -force ../src/fpga/apf/build_id.mif apf/build_id.mif
vlog -sv +define+SYNTHESIS ../src/fpga/core/vb/NECv810/*.sv ../src/fpga/core/vb/VIP/*.sv ../src/fpga/core/vb/VSU/VSU.sv ../src/fpga/core/vb/virtualboy.v ../src/fpga/core/vb/vue.v ../src/fpga/core/vb/vb_cheat_engine.sv ../src/fpga/core/vb/Mem/cache_ram.v ../src/fpga/core/vb/Mem/sdram.sv ../src/fpga/core/vb/Mem/vb_cart_sdram.sv ../src/fpga/core/vb/Mem/vb_cart_rom.sv ../src/fpga/core/vb/Mem/vb_cart_ram_clear.sv ../src/fpga/core/pocket_*.sv ../src/fpga/core/core_top.v ../src/fpga/core/core_bridge_cmd.v ../src/fpga/apf/common.v ../src/fpga/apf/mf_datatable.v tb_top_boot.sv
set game_args {}
if {[info exists env(VB_TEST_ROM)]} { lappend game_args "+ROM=$env(VB_TEST_ROM)" }
if {[info exists env(VB_TEST_MS)]} { lappend game_args "+RUN_MS=$env(VB_TEST_MS)" }
if {[info exists env(VB_TEST_IDEAL)] && $env(VB_TEST_IDEAL) eq "1"} { lappend game_args "+IDEAL_READ_ORDER" }
if {[info exists env(VB_TEST_MENU)] && $env(VB_TEST_MENU) eq "1"} { lappend game_args "+MENU_TEST" }
vsim -c -L altera_mf work.tb_top_boot {*}$game_args
onfinish stop
run -all
quit -code 0
