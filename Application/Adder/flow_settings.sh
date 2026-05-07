#!/usr/bin/env bash
# Default settings for the local (non-Slurm) ZCU104 Vitis flow.
#
# Beginners: start by checking PLATFORM_PATH below. If your Vitis platform is
# installed elsewhere, either edit this file or pass PLATFORM_PATH on the command
# line, for example:
#   PLATFORM_PATH=/path/to/xilinx_zcu104_base_202320_1.xpfm ./build_hls.sh

# Kernel/top-function name. This must match libsrc/src/<kernel>.cpp and the HLS
# top function name used by Vitis.
KERNEL_NAME="${KERNEL_NAME:-adder}"

# Target board and Vitis platform file.
BOARD="${BOARD:-zcu104}"
PLATFORM_PATH="${PLATFORM_PATH:-/opt/xilinx/platforms/xilinx_zcu104_base_202320_1/xilinx_zcu104_base_202320_1.xpfm}"

# Build mode. Keep "hw" for an implementation bitstream for the FPGA.
TARGET="${TARGET:-hw}"

# ZCU104 uses an Arm host. Use x86 only for x86 emulation/host flows.
HOST_ARCH="${HOST_ARCH:-aarch64}"
SYSROOT="${SYSROOT:-}"

# Kernel clock target in MHz.
FREQUENCY="${FREQUENCY:-300}"

# PAC output defaults.
XCLBIN_DIR="${XCLBIN_DIR:-./build_dir.hw.xilinx_zcu104_base_202320_1}"
PAC_CONTAINER="${PAC_CONTAINER:-../../PAC_container}"

# Optional: set this to your local Vitis setup script if v++ is not already in
# PATH. Example:
#   VITIS_SETTINGS=/tools/Xilinx/Vitis/2023.2/settings64.sh ./build_hls.sh
VITIS_SETTINGS="${VITIS_SETTINGS:-}"
