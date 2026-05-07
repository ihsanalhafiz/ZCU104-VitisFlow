#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=Application/Adder/flow_utils.sh
source "$SCRIPT_DIR/flow_utils.sh"
flow_load_settings

show_help() {
  cat <<MSG
Usage: $0 [--kernel NAME] [--board BOARD] [--xclbin FILE] [--xclbin-dir DIR] [--container DIR] [--platform XPFM]

Create a Vitis Platform Assets Container (PAC) from a completed hardware build.

Common examples:
  ./package_pac.sh
  ./package_pac.sh --kernel adder
  ./package_pac.sh --xclbin ./build_dir.hw.xilinx_zcu104_base_202320_1/adder.xclbin
MSG
}

XCLBIN_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -k|--kernel|--name)
      KERNEL_NAME="$2"; shift 2 ;;
    -b|--board)
      BOARD="$2"; shift 2 ;;
    -x|--xclbin)
      XCLBIN_PATH="$2"; shift 2 ;;
    -d|--xclbin-dir)
      XCLBIN_DIR="$2"; shift 2 ;;
    -c|--container)
      PAC_CONTAINER="$2"; shift 2 ;;
    -p|--platform)
      PLATFORM_PATH="$2"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "ERROR: Unknown option: $1" >&2; show_help; exit 1 ;;
  esac
done

cd "$SCRIPT_DIR"
flow_source_vitis

if [[ -z "$XCLBIN_PATH" ]]; then
  XCLBIN_PATH="$XCLBIN_DIR/$KERNEL_NAME.xclbin"
fi

echo "Packaging PAC with:"
echo "  KERNEL_NAME=$KERNEL_NAME"
echo "  BOARD=$BOARD"
echo "  PLATFORM_PATH=$PLATFORM_PATH"
echo "  XCLBIN_PATH=$XCLBIN_PATH"
echo "  PAC_CONTAINER=$PAC_CONTAINER"

./create_vitis_pac.sh \
  --configname "$KERNEL_NAME" \
  --vitis . \
  --board "$BOARD" \
  --xclbin "$XCLBIN_PATH" \
  --container "$PAC_CONTAINER" \
  --platform "$PLATFORM_PATH"
