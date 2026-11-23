onbreak {quit -f}
onerror {quit -f}

vsim -voptargs="+acc"  -L xil_defaultlib -L xbip_utils_v3_0_16 -L c_reg_fd_v12_0_12 -L xbip_dsp48_wrapper_v3_0_7 -L xbip_pipe_v3_0_12 -L c_addsub_v12_0_22 -L mult_gen_v12_0_25 -L axi_utils_v2_0_12 -L cordic_v6_0_26 -L secureip -lib xil_defaultlib xil_defaultlib.cordic_1

set NumericStdNoWarnings 1
set StdArithNoWarnings 1

do {wave.do}

view wave
view structure
view signals

do {cordic_1.udo}

run 1000ns

quit -force
