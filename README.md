# ZCU104 Vitis Flow: Build HLS Kernel, Generate Bitstream, Create PAC

This repository provides a minimal, repeatable flow to:
- Develop an HLS kernel
- Run HLS compilation to produce a kernel `.xo`
- Build the hardware bitstream and `.xclbin`
- Package a Vitis Platform Assets Container (PAC) for ZCU104

The provided example is `Adder`. You can copy it to start your own kernel/application.

## Prerequisites

- Xilinx Vitis 2023.2 installed and available on the build nodes
- ZCU104 platform installed (default path used by this repo):
  - `/opt/xilinx/platforms/xilinx_zcu104_base_202320_1/xilinx_zcu104_base_202320_1.xpfm`
- SLURM access (the flow uses `sbatch`) and a suitable partition/queue
- On clusters using Environment Modules:
  - `module load xilinx/2023.2`

Tip: All provided `*.sbatch` scripts load `xilinx/2023.2` and submit to `fpgaserv`. Adjust these to match your environment.

## Repository Layout (key paths)

- `libsrc/src/` — put your HLS kernel source here (e.g. `mykernel.cpp`)
- `libsrc/include/` — headers for kernels (e.g. add your declarations to `hls_header.h`)
- `Application/Adder/` — example application and build flow for kernel `adder`
  - `Makefile` — controls HLS, bitstream build, host build
  - `hls_check.sbatch` — SLURM job to run HLS (produces `.xo` under `hls_xo/`)
  - `synthesis_kernel.sbatch` — SLURM job to build `.xclbin` (bitstream)
  - `create_vitis_pac.sbatch` — SLURM job to create a PAC using `create_vitis_pac.sh`
  - `create_vitis_pac.sh` — PAC creation script with validation and packaging logic
  - `host_adder.cpp` — example host application

## Quick Start (use the Adder example as-is)

1) Submit HLS compile (produces `.xo` and HLS reports):
   - `cd Application/Adder`
   - `sbatch hls_check.sbatch`

2) Submit hardware build (produces `.xclbin`):
   - `sbatch synthesis_kernel.sbatch`

3) Create a PAC from the built artifacts:
   - `sbatch create_vitis_pac.sbatch -- --name adder`

4) Monitor jobs and logs:
   - `squeue -u $USER`
   - HLS logs: `hls_check_<jobid>.log` / `.err`
   - Build logs: `compile_<jobid>.log` / `.err`
   - PAC logs: `create_pac_<jobid>.log` / `.err`

## Create Your Own Kernel/Application

1) Add your HLS kernel source and headers
   - Put your kernel source in `libsrc/src/`, for example `mykernel.cpp`.
   - Add/declare the top function signature in `libsrc/include/hls_header.h` as needed by your kernel.

2) Create an app folder from the example
   - Copy the example app:
     - `cp -r Application/Adder Application/MyKernel`
   - Inside `Application/MyKernel`, update naming to match your kernel:
     - In `Makefile` change:
       - `KERNEL_COMPILE := mykernel`
       - `HOST_COMPILE := host_mykernel` (optional; adjust host file name accordingly)
       - `HOST_MAIN_SRC := ./$(HOST_COMPILE).cpp` (or point to your host source)
       - `DEVICE := /opt/xilinx/platforms/xilinx_zcu104_base_202320_1/xilinx_zcu104_base_202320_1.xpfm` (adjust if needed)
       - `FREQUENCY := 300` (optional kernel clock target in MHz)
       - `HOST_ARCH := aarch64` (keep for Zynq MPSoC; use `x86` for x86 hosts)

3) Update SLURM scripts for your kernel name
   - Edit `hls_check.sbatch` and set:
     - `make hls_xo KERNEL_COMPILE=mykernel`
   - Edit `synthesis_kernel.sbatch` and set:
     - `make build KERNEL_COMPILE=mykernel`
   - Optionally rename the job names and outputs in the `#SBATCH` lines.

4) Run your flow
   - From `Application/MyKernel`:
     - `sbatch hls_check.sbatch`
     - `sbatch synthesis_kernel.sbatch`
     - Create PAC:
       - `sbatch create_vitis_pac.sbatch -- --name mykernel`
       - Options are described below; defaults target ZCU104.

## What Each Step Does and Where Outputs Go

- HLS (`make hls_xo ...` via `hls_check.sbatch`)
  - Compiles `libsrc/src/<kernel>.cpp` to `<kernel>.xo`
  - Output dir: `Application/<App>/hls_xo/`
  - HLS reports: under `hls_xo/...` and `hls_xo/<kernel>/.../report`

- Hardware build (`make build ...` via `synthesis_kernel.sbatch`)
  - Links kernel objects and produces `<kernel>.xclbin`
  - Default output dir: `Application/<App>/build_dir.hw.xilinx_zcu104_base_202320_1/`
  - Intermediate logs under `_x.hw.xilinx_zcu104_base_202320_1/` and `build_dir.hw...`

- PAC creation (`create_vitis_pac.sbatch` → `create_vitis_pac.sh`)
  - Validates platform files and build outputs
  - Copies boot assets, `system.bit`, and the `.xclbin` into a PAC structure
  - Default PAC output dir: `PAC_container/`
    - `PAC_container/hwconfig/<config>/<board>/` contains boot files, `system.bit`, and `.xclbin`

## PAC Script Usage (details)

Submit via SLURM (note the `--` before script args so SLURM doesn’t parse them):

- `sbatch create_vitis_pac.sbatch -- --name <kernel> [--board zcu104] [--xclbin-dir DIR] [--xclbin FILE] [--container DIR] [--platform FILE]`

Defaults used by the wrapper (`create_vitis_pac.sbatch`):
- `--name/--kernel`: kernel name (default `adder`)
- `--board`: `zcu104` (others supported by the script: zcu102, zcu104, zcu106, zcu111, zcu208, zcu216)
- `--xclbin-dir`: `./build_dir.hw.xilinx_zcu104_base_202320_1`
- `--xclbin`: optional explicit `.xclbin` path (overrides dir/name)
- `--container`: `../../PAC_container`
- `--platform`: `/opt/xilinx/platforms/.../xilinx_zcu104_base_202320_1.xpfm`

Run the packager script directly (without SLURM) if preferred:
- `cd Application/<App>`
- `./create_vitis_pac.sh -n <kernel> -v . -b zcu104 -x ./build_dir.hw.xilinx_zcu104_base_202320_1/<kernel>.xclbin -c ../../PAC_container -p /opt/xilinx/platforms/xilinx_zcu104_base_202320_1/xilinx_zcu104_base_202320_1.xpfm`


## Monitoring and Cleaning

- Monitor SLURM jobs: `squeue -u $USER`
- Inspect logs in your app folder:
  - HLS: `hls_check_<jobid>.log` / `.err`
  - Build: `compile_<jobid>.log` / `.err`
  - PAC: `create_pac_<jobid>.log` / `.err`
- Clean intermediates:
  - `make clean` (remove non-hw files)
  - `make cleanall` (remove all generated outputs including `build_dir*`, `package.*`, `sd_card*`)

## Troubleshooting

- Incorrect module/platform
  - Ensure `module load xilinx/2023.2` (or set your environment appropriately).
  - Verify `DEVICE` in the `Makefile` points to a valid `.xpfm`.

- HLS does not find your kernel
  - Confirm your file exists: `libsrc/src/<kernel>.cpp`.
  - Ensure `KERNEL_COMPILE := <kernel>` in the app `Makefile` and in `hls_check.sbatch`.

- No `.xclbin` produced
  - Check `compile_<jobid>.log` and `build_dir.hw.../` for errors.
  - Run `make print` to verify `TARGET`, `DEVICE`, and `KERNEL` values.

- PAC creation fails
  - Confirm platform directory structure (boot files) exists under `/opt/xilinx/platforms/.../sw/<platform_name>/boot`.
  - Ensure `<kernel>.xclbin` is present in `build_dir.hw.<platform_name>/`.
  - Re-run with `-h/--help` to check required arguments.

## Notes

- Defaults target ZCU104; other Zynq boards are supported by the PAC script but will require a matching platform and app build.
- Adjust `#SBATCH` directives in the SLURM scripts (time, partition, CPUs, memory) to fit your cluster.
