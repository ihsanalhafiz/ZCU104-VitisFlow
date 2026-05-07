# ZCU104 Vitis Flow: Beginner-Friendly HLS to FPGA Template

This repository is a small public template for building a Vitis HLS kernel for
the **AMD/Xilinx ZCU104** board from a normal Ubuntu terminal. It does **not**
require Slurm, `sbatch`, or a cluster job scheduler.

The example application is an `Adder` kernel. Use it first to verify your Vitis
installation, then copy it when you are ready to create your own kernel.

## What this flow does

Starting from C/C++ HLS code, the flow helps you:

1. Compile the HLS kernel into a Vitis kernel object (`.xo`).
2. Run hardware implementation and generate an FPGA binary (`.xclbin`).
3. Package the generated boot assets, bitstream, and `.xclbin` into a Vitis
   Platform Assets Container (PAC) for Ubuntu-based ZCU104 deployment.

## Prerequisites

Install or prepare these items before running the flow:

- Ubuntu development machine with AMD/Xilinx **Vitis 2023.2** installed.
- ZCU104 base platform installed. The default path used by this repository is:

  ```bash
  /opt/xilinx/platforms/xilinx_zcu104_base_202320_1/xilinx_zcu104_base_202320_1.xpfm
  ```

- Vitis command-line tools available in your shell. For a local installation,
  this usually means running a command similar to:

  ```bash
  source /tools/Xilinx/Vitis/2023.2/settings64.sh
  ```

  If your path is different, use the setup script that matches your Vitis
  installation.

> **Tip:** If you do not want to source Vitis manually before each command, pass
> `VITIS_SETTINGS` when you run a script, for example:
>
> ```bash
> VITIS_SETTINGS=/tools/Xilinx/Vitis/2023.2/settings64.sh ./build_hls.sh
> ```

## Repository layout

Key files and folders:

```text
libsrc/src/adder.cpp                 # Example HLS kernel source
libsrc/include/hls_header.h          # HLS function declarations shared by host/kernel code
Application/Adder/                   # Example Vitis application flow
Application/Adder/flow_settings.sh   # Default local build settings to edit first
Application/Adder/build_hls.sh       # Step 1: build the .xo kernel object
Application/Adder/build_hardware.sh  # Step 2: build the hardware .xclbin
Application/Adder/package_pac.sh     # Step 3: create the PAC container
Application/Adder/run_full_flow.sh   # Optional: run steps 1-3 in order
Application/Adder/create_vitis_pac.sh # Lower-level PAC creation helper
Application/Adder/Makefile           # Vitis build rules used by the scripts
```

## Quick start: build the Adder example

Open a terminal at the repository root, then follow these steps.

### 1. Load the Vitis environment

```bash
source /tools/Xilinx/Vitis/2023.2/settings64.sh
```

Check that `v++` is visible:

```bash
v++ --version
```

If `v++` is not found, verify the path to `settings64.sh` for your machine.

### 2. Review the local settings

```bash
cd Application/Adder
nano flow_settings.sh
```

For most users, the most important line is `PLATFORM_PATH`. Make sure it points
to your installed ZCU104 `.xpfm` file.

Default settings are:

```bash
KERNEL_NAME=adder
BOARD=zcu104
PLATFORM_PATH=/opt/xilinx/platforms/xilinx_zcu104_base_202320_1/xilinx_zcu104_base_202320_1.xpfm
TARGET=hw
HOST_ARCH=aarch64
FREQUENCY=300
PAC_CONTAINER=../../PAC_container
```

You may edit `flow_settings.sh`, or override values on the command line.

### 3. Build the HLS kernel object (`.xo`)

```bash
./build_hls.sh
```

Expected main output:

```text
Application/Adder/hls_xo/adder.xo
```

This step also produces HLS reports inside the `hls_xo/` directory.

### 4. Build the FPGA hardware binary (`.xclbin`)

```bash
./build_hardware.sh
```

Expected main output:

```text
Application/Adder/build_dir.hw.xilinx_zcu104_base_202320_1/adder.xclbin
```

This is the slowest step. Depending on your machine, it can take tens of minutes
or several hours.

### 5. Create the PAC container

```bash
./package_pac.sh
```

Expected output location:

```text
PAC_container/hwconfig/adder/zcu104/
```

The PAC folder contains boot collateral, `system.bit`, the `.xclbin`, and a
`manifest.yaml` file.

### Optional: run everything with one command

After checking `flow_settings.sh`, you can run all three steps in order:

```bash
./run_full_flow.sh
```

For beginners, running the separate steps first is recommended because it is
easier to see where a problem occurs.

## Command-line overrides

All wrapper scripts use the defaults from `flow_settings.sh`, but common values
can also be passed at runtime.

Examples:

```bash
./build_hls.sh --kernel adder
./build_hardware.sh --kernel adder --frequency 250
./package_pac.sh --kernel adder --board zcu104
PLATFORM_PATH=/my/platform/path/xilinx_zcu104_base_202320_1.xpfm ./build_hls.sh
VITIS_SETTINGS=/tools/Xilinx/Vitis/2023.2/settings64.sh ./build_hardware.sh
```

## Creating your own kernel/application

Use the Adder example as a known-good starting point.

### 1. Add your HLS code

- Add your kernel source in `libsrc/src/`, for example:

  ```text
  libsrc/src/mykernel.cpp
  ```

- Add or update the function declaration in:

  ```text
  libsrc/include/hls_header.h
  ```

The kernel file name and top function should match the kernel name you build.
For example, `mykernel.cpp` should provide a top function named `mykernel` unless
you intentionally configure Vitis differently.

### 2. Copy the example application

From the repository root:

```bash
cp -r Application/Adder Application/MyKernel
cd Application/MyKernel
```

### 3. Update the settings

Edit `Application/MyKernel/flow_settings.sh`:

```bash
KERNEL_NAME="${KERNEL_NAME:-mykernel}"
```

Also review:

- `PLATFORM_PATH` if your ZCU104 platform is not installed in the default path.
- `FREQUENCY` if you need a different kernel clock target.
- `HOST_ARCH`; keep `aarch64` for the ZCU104 Arm target.
- `SYSROOT` if your host build needs an Arm sysroot.

### 4. Update or replace host code

The Vitis host application for the example is:

```text
Application/Adder/host_adder.cpp
```

For your own application, create a matching host file and update these Makefile
variables if needed:

```make
HOST_COMPILE := host_mykernel
HOST_MAIN_SRC := ./$(HOST_COMPILE).cpp
```

### 5. Run the local flow

From your application folder:

```bash
./build_hls.sh
./build_hardware.sh
./package_pac.sh
```

## What each script does

### `build_hls.sh`

Runs:

```bash
make hls_xo KERNEL_COMPILE=<kernel>
```

Main outputs:

- `hls_xo/<kernel>.xo`
- HLS reports under `hls_xo/`

### `build_hardware.sh`

Runs:

```bash
make build KERNEL_COMPILE=<kernel>
```

Main outputs:

- `build_dir.hw.xilinx_zcu104_base_202320_1/<kernel>.xclbin`
- Vivado/Vitis implementation logs and intermediate files

### `package_pac.sh`

Runs `create_vitis_pac.sh` with beginner-friendly defaults.

Main outputs:

- `PAC_container/hwconfig/<kernel>/zcu104/`
- `PAC_container/hwconfig/<kernel>/manifest.yaml`

## Cleaning generated files

From an application folder such as `Application/Adder`:

```bash
make clean
```

For a deeper clean:

```bash
make cleanall
```

Generated build directories such as `hls_xo/`, `_x.hw.../`, `build_dir.hw.../`,
`package.hw/`, and log files are ignored by Git.

## Troubleshooting

### `v++ was not found in PATH`

Load the Vitis environment first:

```bash
source /tools/Xilinx/Vitis/2023.2/settings64.sh
```

Or run the wrapper with `VITIS_SETTINGS`:

```bash
VITIS_SETTINGS=/tools/Xilinx/Vitis/2023.2/settings64.sh ./build_hls.sh
```

### Platform `.xpfm` file not found

Edit `Application/Adder/flow_settings.sh` and set `PLATFORM_PATH` to your local
ZCU104 platform file, or override it when running a command:

```bash
PLATFORM_PATH=/path/to/xilinx_zcu104_base_202320_1.xpfm ./build_hardware.sh
```

### Kernel source not found

Make sure the kernel name matches the source file:

```text
KERNEL_NAME=adder       -> libsrc/src/adder.cpp
KERNEL_NAME=mykernel    -> libsrc/src/mykernel.cpp
```

### PAC packaging cannot find the hardware build directory

Run the hardware build first:

```bash
./build_hardware.sh
```

Then run:

```bash
./package_pac.sh
```

### Build timing or implementation fails

Hardware implementation is sensitive to timing constraints, platform versions,
and kernel design. Start by checking:

- The terminal output from `./build_hardware.sh`.
- Vitis/Vivado logs under `_x.hw.xilinx_zcu104_base_202320_1/` and
  `build_dir.hw.xilinx_zcu104_base_202320_1/`.
- Whether `FREQUENCY` in `flow_settings.sh` is too aggressive for your design.

## Notes for former Slurm users

Older revisions of this template used `*.sbatch` files and commands such as
`sbatch hls_check.sbatch`. Those files have been replaced by normal local shell
scripts:

```text
hls_check.sbatch          -> build_hls.sh
synthesis_kernel.sbatch   -> build_hardware.sh
create_vitis_pac.sbatch   -> package_pac.sh
```

Run the scripts directly from a regular Ubuntu terminal. If you personally use a
cluster, you can still wrap these scripts in your own scheduler commands, but the
template no longer depends on Slurm.
