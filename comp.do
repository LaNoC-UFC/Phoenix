#exit -sim
vlib work
vmap work work

# Packages
vcom -work work -93 -explicit NoC/Phoenix_package.vhd
vcom -work work -93 -explicit NoC/Table_package.vhd
vcom -work work -93 -explicit NoC/HammingPack16.vhd

# Hamming and fault blocks
vcom -work work -93 -explicit NoC/Encoder.vhd
vcom -work work -93 -explicit NoC/Decoder.vhd
vcom -work work -93 -explicit NoC/FaultInjector.vhd

# FPPM block
vcom -work work -93 -explicit NoC/FPPM_AA00.vhd

# NoC
vcom -work work -93 -explicit NoC/Phoenix_RM.vhd
vcom -work work -93 -explicit NoC/fifo_buffer.vhd
vcom -work work -93 -explicit NoC/Phoenix_buffer.vhd
vcom -work work -93 -explicit NoC/outputArbiter.vhd
vcom -work work -93 -explicit NoC/FaultDetection.vhd
vcom -work work -93 -explicit NoC/Phoenix_switchcontrol.vhd
vcom -work work -93 -explicit NoC/Phoenix_crossbar.vhd
vcom -work work -93 -explicit NoC/RouterCC.vhd
vcom -work work -93 -explicit NoC/NOC.vhd

# TestBench
vcom -work work -93 -explicit outputModule.vhd
vcom -work work -93 -explicit inputModule.vhd
vcom -work work -93 -explicit topNoC.vhd

#quit -f