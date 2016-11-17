exit -sim
vlib work
vmap work work

# Packages
vcom -work work -93 -explicit NoC/Phoenix_package.vhd
vcom -work work -93 -explicit NoC/Table_package.vhd
vcom -work work -93 -explicit NoC/HammingPack16.vhd

# Hamming and fault blocks
vcom -work work -93 -explicit NoC/FaultInjector.vhd
vcom -work work -93 -explicit NoC/Phoenix_buffer.vhd

# TestBench
vcom -work work -93 -explicit tests/fault_injector_test.vhd
vcom -work work -93 -explicit tests/phoenix_buffer_test.vhd

vsim work.fault_injector_test
run 1 ms; exit -sim
vsim work.phoenix_buffer_test(happy_path)
run 1 ms; exit -sim
vsim work.phoenix_buffer_test(data_input_test)
run 1 ms; exit -sim
vsim work.phoenix_buffer_test(data_output_test)
run 1 ms; exit -sim
