#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
  cat <<MSG
Usage: $0 [--host NAME]

Compile the host application natively on the ZCU104 Ubuntu system.
Run this after the PAC has been installed, activated, and the board has rebooted.

Common examples:
  ./build_host_on_fpga.sh
  ./build_host_on_fpga.sh --host host_adder
MSG
}

HOST_COMPILE="${HOST_COMPILE:-host_adder}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      HOST_COMPILE="$2"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "ERROR: Unknown option: $1" >&2; show_help; exit 1 ;;
  esac
done

cd "$SCRIPT_DIR"

# In this inherited Vitis Makefile, HOST_ARCH=x86 selects the native g++ build
# path. On the ZCU104 board, native g++ still produces an aarch64 executable.
make host \
  HOST_ARCH=x86 \
  HOST_COMPILE="$HOST_COMPILE" \
  XILINX_XRT="${XILINX_XRT:-/usr}" \
  XILINX_VIVADO="${XILINX_VIVADO:-/usr}"
