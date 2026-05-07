#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

KERNEL_ARGS=()
HARDWARE_ONLY_ARGS=()
PACKAGE_ARGS=()

show_help() {
  cat <<MSG
Usage: $0 [--kernel NAME] [--platform XPFM] [--frequency MHz] [--host-arch ARCH] [--sysroot DIR] [--board BOARD] [--container DIR]

Run the full local Vitis flow:
  1. HLS compile (.xo)
  2. Hardware implementation (.xclbin)
  3. PAC packaging
MSG
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -k|--kernel|--name)
      KERNEL_ARGS+=("$1" "$2")
      PACKAGE_ARGS+=("$1" "$2")
      shift 2 ;;
    -p|--platform)
      KERNEL_ARGS+=("$1" "$2")
      PACKAGE_ARGS+=("$1" "$2")
      shift 2 ;;
    -f|--frequency)
      KERNEL_ARGS+=("$1" "$2")
      shift 2 ;;
    --host-arch|--sysroot)
      HARDWARE_ONLY_ARGS+=("$1" "$2")
      shift 2 ;;
    -b|--board|-c|--container)
      PACKAGE_ARGS+=("$1" "$2")
      shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    *)
      echo "ERROR: Unknown option: $1" >&2; show_help; exit 1 ;;
  esac
done

cat <<'MSG'
Running the full local Vitis flow:
  1. HLS compile (.xo)
  2. Hardware implementation (.xclbin)
  3. PAC packaging

The hardware implementation step can take a long time.
MSG

"$SCRIPT_DIR/build_hls.sh" "${KERNEL_ARGS[@]}"
"$SCRIPT_DIR/build_hardware.sh" "${KERNEL_ARGS[@]}" "${HARDWARE_ONLY_ARGS[@]}"
"$SCRIPT_DIR/package_pac.sh" "${PACKAGE_ARGS[@]}"
