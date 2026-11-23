transcript off
onbreak {quit -force}
onerror {quit -force}
transcript on

vlib work
vlib activehdl/xbip_utils_v3_0_16
vlib activehdl/c_reg_fd_v12_0_12
vlib activehdl/xbip_dsp48_wrapper_v3_0_7
vlib activehdl/xbip_pipe_v3_0_12
vlib activehdl/c_addsub_v12_0_22
vlib activehdl/mult_gen_v12_0_25
vlib activehdl/axi_utils_v2_0_12
vlib activehdl/cordic_v6_0_26
vlib activehdl/xil_defaultlib

vmap xbip_utils_v3_0_16 activehdl/xbip_utils_v3_0_16
vmap c_reg_fd_v12_0_12 activehdl/c_reg_fd_v12_0_12
vmap xbip_dsp48_wrapper_v3_0_7 activehdl/xbip_dsp48_wrapper_v3_0_7
vmap xbip_pipe_v3_0_12 activehdl/xbip_pipe_v3_0_12
vmap c_addsub_v12_0_22 activehdl/c_addsub_v12_0_22
vmap mult_gen_v12_0_25 activehdl/mult_gen_v12_0_25
vmap axi_utils_v2_0_12 activehdl/axi_utils_v2_0_12
vmap cordic_v6_0_26 activehdl/cordic_v6_0_26
vmap xil_defaultlib activehdl/xil_defaultlib

vcom -work xbip_utils_v3_0_16 -93  \
"../../../ipstatic/hdl/xbip_utils_v3_0_rfs.vhd" \

vcom -work c_reg_fd_v12_0_12 -93  \
"../../../ipstatic/hdl/c_reg_fd_v12_0_vh_rfs.vhd" \

vcom -work xbip_dsp48_wrapper_v3_0_7 -93  \
"../../../ipstatic/hdl/xbip_dsp48_wrapper_v3_0_vh_rfs.vhd" \

vcom -work xbip_pipe_v3_0_12 -93  \
"../../../ipstatic/hdl/xbip_pipe_v3_0_rfs.vhd" \

vcom -work c_addsub_v12_0_22 -93  \
"../../../ipstatic/hdl/c_addsub_v12_0_rfs.vhd" \

vcom -work mult_gen_v12_0_25 -93  \
"../../../ipstatic/hdl/mult_gen_v12_0_rfs.vhd" \

vcom -work axi_utils_v2_0_12 -93  \
"../../../ipstatic/hdl/axi_utils_v2_0_vh_rfs.vhd" \

vcom -work cordic_v6_0_26 -93  \
"../../../ipstatic/hdl/cordic_v6_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -93  \
"../../../../project_FOC.gen/sources_1/ip/cordic_1/sim/cordic_1.vhd" \


