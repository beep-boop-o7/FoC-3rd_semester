vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/xbip_utils_v3_0_16
vlib modelsim_lib/msim/c_reg_fd_v12_0_12
vlib modelsim_lib/msim/xbip_dsp48_wrapper_v3_0_7
vlib modelsim_lib/msim/xbip_pipe_v3_0_12
vlib modelsim_lib/msim/c_addsub_v12_0_22
vlib modelsim_lib/msim/mult_gen_v12_0_25
vlib modelsim_lib/msim/axi_utils_v2_0_12
vlib modelsim_lib/msim/cordic_v6_0_26
vlib modelsim_lib/msim/xil_defaultlib

vmap xbip_utils_v3_0_16 modelsim_lib/msim/xbip_utils_v3_0_16
vmap c_reg_fd_v12_0_12 modelsim_lib/msim/c_reg_fd_v12_0_12
vmap xbip_dsp48_wrapper_v3_0_7 modelsim_lib/msim/xbip_dsp48_wrapper_v3_0_7
vmap xbip_pipe_v3_0_12 modelsim_lib/msim/xbip_pipe_v3_0_12
vmap c_addsub_v12_0_22 modelsim_lib/msim/c_addsub_v12_0_22
vmap mult_gen_v12_0_25 modelsim_lib/msim/mult_gen_v12_0_25
vmap axi_utils_v2_0_12 modelsim_lib/msim/axi_utils_v2_0_12
vmap cordic_v6_0_26 modelsim_lib/msim/cordic_v6_0_26
vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib

vcom -work xbip_utils_v3_0_16  -93  \
"../../../ipstatic/hdl/xbip_utils_v3_0_rfs.vhd" \

vcom -work c_reg_fd_v12_0_12  -93  \
"../../../ipstatic/hdl/c_reg_fd_v12_0_vh_rfs.vhd" \

vcom -work xbip_dsp48_wrapper_v3_0_7  -93  \
"../../../ipstatic/hdl/xbip_dsp48_wrapper_v3_0_vh_rfs.vhd" \

vcom -work xbip_pipe_v3_0_12  -93  \
"../../../ipstatic/hdl/xbip_pipe_v3_0_rfs.vhd" \

vcom -work c_addsub_v12_0_22  -93  \
"../../../ipstatic/hdl/c_addsub_v12_0_rfs.vhd" \

vcom -work mult_gen_v12_0_25  -93  \
"../../../ipstatic/hdl/mult_gen_v12_0_rfs.vhd" \

vcom -work axi_utils_v2_0_12  -93  \
"../../../ipstatic/hdl/axi_utils_v2_0_vh_rfs.vhd" \

vcom -work cordic_v6_0_26  -93  \
"../../../ipstatic/hdl/cordic_v6_0_vh_rfs.vhd" \

vcom -work xil_defaultlib  -93  \
"../../../../project_FOC.gen/sources_1/ip/cordic_1/sim/cordic_1.vhd" \


