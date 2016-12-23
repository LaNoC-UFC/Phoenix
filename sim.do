file mkdir Out
quit -sim
quietly set seed1 [expr {int(1 + 2147483562*rand())}]; # [1,2147483562]
quietly set seed2 [expr {int(1 + 2147483398*rand())}]; # [1,2147483398]
vsim -voptargs="+acc" -quiet -G SEED_VAL_1=$seed1 -G SEED_VAL_2=$seed2 work.topnoc
set StdArithNoWarnings 1
run 100 ms
quit -sim
quit -f
