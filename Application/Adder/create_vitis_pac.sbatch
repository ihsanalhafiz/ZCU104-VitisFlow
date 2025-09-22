#!/bin/bash
#SBATCH --job-name=create_pac           # Job name
#SBATCH --output=create_pac_%j.log         # Output file (%j expands to jobID)
#SBATCH --error=create_pac_%j.err          # Error file
#SBATCH --time=02:00:00                 # Max walltime (hh:mm:ss)
#SBATCH --partition=fpgaserv             # Partition/queue name (adjust to your cluster)
#SBATCH --ntasks=1                      # Number of tasks
#SBATCH --cpus-per-task=4               # Number of CPU cores per task
#SBATCH --mem=8G                        # Memory per node

# --- Load required modules (example) ---
module purge
module load xilinx/2023.2

# --- Parameters (overridable by env or script args) ---
# Defaults can be overridden by exporting env vars or passing flags to this script.
# Examples:
#   sbatch create_vitis_pac.sbatch -- --name mykernel
#   sbatch --export=ALL,KERNEL_NAME=mykernel /path/to/create_vitis_pac.sbatch

# Defaults
KERNEL_NAME="${KERNEL_NAME:-adder}"
BOARD="${BOARD:-zcu104}"
XCLBIN_DIR="${XCLBIN_DIR:-./build_dir.hw.xilinx_zcu104_base_202320_1}"
XCLBIN_PATH_DEFAULT="$XCLBIN_DIR/${KERNEL_NAME}.xclbin"
XCLBIN_PATH="${XCLBIN_PATH:-$XCLBIN_PATH_DEFAULT}"
CONTAINER_DIR="${CONTAINER_DIR:-../../PAC_container}"
PLATFORM_PATH="${PLATFORM_PATH:-/opt/xilinx/platforms/xilinx_zcu104_base_202320_1/xilinx_zcu104_base_202320_1.xpfm}"

show_help() {
  echo "Usage: $0 [--name KERNEL] [--board BOARD] [--xclbin-dir DIR] [--xclbin FILE] [--container DIR] [--platform FILE]"
  echo "  -n, --name, --kernel   Kernel name (default: $KERNEL_NAME)"
  echo "  -b, --board            Board name (default: $BOARD)"
  echo "  -d, --xclbin-dir       Directory containing the .xclbin (default: $XCLBIN_DIR)"
  echo "  -x, --xclbin           Explicit .xclbin file path (overrides dir/name)"
  echo "  -c, --container        PAC container directory (default: $CONTAINER_DIR)"
  echo "  -p, --platform         Platform .xpfm path (default: $PLATFORM_PATH)"
  echo "  -h, --help             Show this help"
  echo "\nNote: When submitting with sbatch, place '--' before script args to avoid sbatch parsing them."
}

# Parse script arguments (after the '--' separator in sbatch)
user_set_xclbin_path=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--name|--kernel)
      KERNEL_NAME="$2"; shift 2 ;;
    -b|--board)
      BOARD="$2"; shift 2 ;;
    -d|--xclbin-dir)
      XCLBIN_DIR="$2"; shift 2 ;;
    -x|--xclbin)
      XCLBIN_PATH="$2"; user_set_xclbin_path=true; shift 2 ;;
    -c|--container)
      CONTAINER_DIR="$2"; shift 2 ;;
    -p|--platform)
      PLATFORM_PATH="$2"; shift 2 ;;
    -h|--help)
      show_help; exit 0 ;;
    --)
      shift; break ;;
    *)
      echo "Unknown option: $1"; show_help; exit 1 ;;
  esac
done

# Derive XCLBIN path from dir/name if user did not explicitly set it
if [[ "$user_set_xclbin_path" != true ]]; then
  XCLBIN_PATH="$XCLBIN_DIR/${KERNEL_NAME}.xclbin"
fi

# --- Run compilation ---
chmod +x create_vitis_pac.sh
./create_vitis_pac.sh -n "$KERNEL_NAME" -v . -b "$BOARD" -x "$XCLBIN_PATH" -c "$CONTAINER_DIR" -p "$PLATFORM_PATH"
