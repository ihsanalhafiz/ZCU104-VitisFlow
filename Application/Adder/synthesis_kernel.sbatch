#!/bin/bash
#SBATCH --job-name=synthesis_adder      # Job name
#SBATCH --output=compile_%j.log         # Output file (%j expands to jobID)
#SBATCH --error=compile_%j.err          # Error file
#SBATCH --time=02:00:00                 # Max walltime (hh:mm:ss)
#SBATCH --partition=fpgaserv             # Partition/queue name (adjust to your cluster)
#SBATCH --ntasks=1                      # Number of tasks
#SBATCH --cpus-per-task=4               # Number of CPU cores per task
#SBATCH --mem=8G                        # Memory per node

# --- Load required modules (example) ---
module purge
module load xilinx/2023.2

# --- Run compilation ---
make build KERNEL_COMPILE=adder
