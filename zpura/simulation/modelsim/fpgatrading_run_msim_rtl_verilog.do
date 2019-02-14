transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -vlog01compat -work work +incdir+/home/andreas/fpga/zpura/memory/sdram {/home/andreas/fpga/zpura/memory/sdram/sdram_controller.v}
vlog -sv -work work +incdir+/home/andreas/fpga/zpura {/home/andreas/fpga/zpura/zpura.sv}
vlog -sv -work work +incdir+/home/andreas/fpga/zpura/memory {/home/andreas/fpga/zpura/memory/memory_controller.sv}

