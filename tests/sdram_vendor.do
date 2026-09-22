onerror {quit -code 1}
vlib work
set questa_root [file dirname [file dirname [info nameofexecutable]]]
vmap altera_mf [file join $questa_root intel verilog altera_mf]
vlog -sv +define+SYNTHESIS ../src/fpga/core/vb/Mem/sdram.sv ../src/fpga/core/vb/Mem/vb_cart_sdram.sv ../src/fpga/core/vb/Mem/vb_cart_rom.sv tb_sdram.sv
vsim -c -L altera_mf work.tb_sdram
onfinish stop
run -all
quit -code 0
