#!/bin/bash
#SBATCH --job-name=hls_check      # Job name
#SBATCH --output=hls_check_%j.log         # Output file (%j expands to jobID)
#SBATCH --error=hls_check_%j.err          # Error file
#SBATCH --time=02:00:00                 # Max walltime (hh:mm:ss)
#SBATCH --partition=fpgaserv             # Partition/queue name (adjust to your cluster)
#SBATCH --ntasks=1                      # Number of tasks
#SBATCH --cpus-per-task=4               # Number of CPU cores per task
#SBATCH --mem=8G                        # Memory per node

# --- Load required modules (example) ---
module purge
module load xilinx/2023.2

# --- Run compilation ---
make hls_xo KERNEL_COMPILE=adder
