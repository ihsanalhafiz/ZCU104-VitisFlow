#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Application/Adder/flow_utils.sh
source "$SCRIPT_DIR/flow_utils.sh"
flow_load_settings

show_help() {
  cat <<MSG
Usage: $0 [--kernel NAME] [--platform XPFM] [--frequency MHz]

Build only the HLS kernel object (.xo).

Common examples:
  ./build_hls.sh
  ./build_hls.sh --kernel adder
  PLATFORM_PATH=/path/to/xilinx_zcu104_base_202320_1.xpfm ./build_hls.sh
MSG
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -k|--kernel|--name)
      KERNEL_NAME="$2"; shift 2 ;;
    -p|--platform)
      PLATFORM_PATH="$2"; shift 2 ;;
    -f|--frequency)
      FREQUENCY="$2"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "ERROR: Unknown option: $1" >&2; show_help; exit 1 ;;
  esac
done

cd "$SCRIPT_DIR"
flow_source_vitis
flow_require_vitis
flow_print_config

make hls_xo \
  KERNEL_COMPILE="$KERNEL_NAME" \
  DEVICE="$PLATFORM_PATH" \
  TARGET="$TARGET" \
  FREQUENCY="$FREQUENCY"
