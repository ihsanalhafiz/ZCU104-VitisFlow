#!/usr/bin/env bash
# Shared helper functions for the local ZCU104 Vitis flow scripts.

flow_script_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
}

flow_load_settings() {
  local script_dir
  script_dir="$(flow_script_dir)"
  # shellcheck source=Application/Adder/flow_settings.sh
  source "$script_dir/flow_settings.sh"
}

flow_source_vitis() {
  if [[ -n "${VITIS_SETTINGS:-}" ]]; then
    if [[ ! -f "$VITIS_SETTINGS" ]]; then
      echo "ERROR: VITIS_SETTINGS points to a missing file: $VITIS_SETTINGS" >&2
      return 1
    fi
    # shellcheck disable=SC1090
    source "$VITIS_SETTINGS"
  fi
}

flow_require_vitis() {
  if [[ -z "${XILINX_VITIS:-}" ]] || ! command -v v++ >/dev/null 2>&1; then
    cat >&2 <<'MSG'
ERROR: the Vitis command-line environment is not ready.

Expected:
  - XILINX_VITIS is set
  - v++ is available in PATH

Load the Xilinx/Vitis environment first, for example:
  source /tools/Xilinx/Vitis/2023.2/settings64.sh

Or run the script with VITIS_SETTINGS set:
  VITIS_SETTINGS=/tools/Xilinx/Vitis/2023.2/settings64.sh ./build_hls.sh
MSG
    return 1
  fi
}

flow_print_config() {
  echo "Using configuration:"
  echo "  KERNEL_NAME=$KERNEL_NAME"
  echo "  BOARD=$BOARD"
  echo "  PLATFORM_PATH=$PLATFORM_PATH"
  echo "  TARGET=$TARGET"
  echo "  HOST_ARCH=$HOST_ARCH"
  echo "  SYSROOT=${SYSROOT:-<not set>}"
  echo "  FREQUENCY=$FREQUENCY MHz"
}
