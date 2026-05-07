#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Application/Adder/flow_utils.sh
source "$SCRIPT_DIR/flow_utils.sh"
flow_load_settings

show_help() {
  cat <<MSG
Usage: $0 [--kernel NAME] [--platform XPFM] [--frequency MHz] [--host-arch ARCH] [--sysroot DIR]

Build the hardware implementation (.xclbin). This step can take a long time.

Common examples:
  ./build_hardware.sh
  ./build_hardware.sh --kernel adder
  SYSROOT=/path/to/sysroot ./build_hardware.sh
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
    --host-arch)
      HOST_ARCH="$2"; shift 2 ;;
    --sysroot)
      SYSROOT="$2"; shift 2 ;;
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

echo "Starting hardware build. This may take from tens of minutes to several hours."
make build \
  KERNEL_COMPILE="$KERNEL_NAME" \
  DEVICE="$PLATFORM_PATH" \
  TARGET="$TARGET" \
  HOST_ARCH="$HOST_ARCH" \
  SYSROOT="$SYSROOT" \
  FREQUENCY="$FREQUENCY"
