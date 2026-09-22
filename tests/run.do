onerror {quit -code 1}
vlib work
vlog -sv ../src/fpga/core/pocket_rom_loader.sv ../src/fpga/core/pocket_controls.sv ../src/fpga/core/pocket_save_ram.sv ../src/fpga/core/pocket_audio.sv ../src/fpga/core/pocket_video.sv ../src/fpga/core/pocket_output_probe.sv tb_pocket.sv tb_video.sv tb_output_probe.sv
vsim -c work.tb_pocket
onfinish stop
run -all
quit -sim
vsim -c work.tb_video
onfinish stop
run -all
quit -sim
vsim -c work.tb_output_probe
onfinish stop
run -all
quit -sim
vlog -sv ../src/fpga/core/vb/Mem/sdram.sv ../src/fpga/core/vb/Mem/vb_cart_sdram.sv ../src/fpga/core/vb/Mem/vb_cart_rom.sv tb_sdram.sv
vsim -c work.tb_sdram
onfinish stop
run -all
quit -sim
vlog -sv ../src/fpga/core/pocket_wram.sv tb_wram.sv
vsim -c work.tb_wram
onfinish stop
run -all
quit -sim
vlog -sv ../src/fpga/core/vb/NECv810/necv810_integer_engine.sv ../src/fpga/core/vb/NECv810/necv810_fp_engine.sv reference_integer_engine.sv reference_fp_engine.sv tb_math.sv
vsim -c work.tb_math
onfinish stop
run -all
quit -sim
vlog -sv +define+SYNTHESIS ../src/fpga/core/vb/NECv810/*.sv ../src/fpga/core/vb/VIP/*.sv ../src/fpga/core/vb/VSU/VSU.sv ../src/fpga/core/vb/virtualboy.v ../src/fpga/core/vb/vue.v ../src/fpga/core/vb/vb_cheat_engine.sv ../src/fpga/core/vb/Mem/cache_ram.v ../src/fpga/core/pocket_wram.sv ../src/fpga/core/pocket_save_ram.sv tb_boot.sv
vsim -c work.tb_boot
onfinish stop
run -all
quit -sim
vlog -sv +define+SYNTHESIS ../src/fpga/core/vb/VIP/*.sv tb_hbias_math.sv
vsim -c work.tb_hbias_math
onfinish stop
run -all
quit -sim
do top_boot.do
