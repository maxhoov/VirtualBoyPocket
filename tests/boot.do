onerror {quit -code 1}
vlib work
vlog -sv +define+SYNTHESIS ../src/fpga/core/vb/NECv810/*.sv ../src/fpga/core/vb/VIP/*.sv ../src/fpga/core/vb/VSU/VSU.sv ../src/fpga/core/vb/virtualboy.v ../src/fpga/core/vb/vue.v ../src/fpga/core/vb/vb_cheat_engine.sv ../src/fpga/core/vb/Mem/cache_ram.v ../src/fpga/core/pocket_wram.sv ../src/fpga/core/pocket_save_ram.sv tb_boot.sv
vsim -c work.tb_boot
onfinish stop
run -all
quit -code 0
