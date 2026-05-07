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
Application/Adder/build_host_on_fpga.sh # Step 4: compile host code on ZCU104 Ubuntu
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

### 6. Deploy and run on the ZCU104 board

The build-machine steps above create the FPGA hardware, but the design is not
running on the board yet. To execute it on the physical ZCU104, continue with
[Run on the FPGA board](#run-on-the-fpga-board-zcu104-ubuntu--xlnx-config--pac--host).

### Optional: run everything with one command

After checking `flow_settings.sh`, you can run all three steps in order:

```bash
./run_full_flow.sh
```

For beginners, running the separate steps first is recommended because it is
easier to see where a problem occurs.


## Run on the FPGA board: ZCU104 Ubuntu + xlnx-config + PAC + host

This section is the board-side part of the flow. Run the HLS/hardware/PAC build
on your development machine first, then use these steps to boot the ZCU104,
activate the generated hardware, compile the host application directly on the
board, and execute it.

The commands below assume the PAC configuration name is `adder`, which is the
repository default. If you changed `KERNEL_NAME`, replace `adder` with your own
configuration/kernel name.


### Official board-side references

- [Getting Started with Certified Ubuntu 22.04 LTS for Xilinx Devices](https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/2363129857/Getting+Started+with+Certified+Ubuntu+22.04+LTS+for+Xilinx+Devices)
- [xlnx-config Snap for Certified Ubuntu on Xilinx Devices](https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/2057043969/Snaps+-+xlnx-config+Snap+for+Certified+Ubuntu+on+Xilinx+Devices)

### 1. Install Certified Ubuntu for Xilinx Devices on the ZCU104

1. Download the Certified Ubuntu for Xilinx Devices image for ZCU104 from the
   official Ubuntu/AMD page.
2. Write the image to a 16 GB or larger microSD card using a disk-imaging tool
   such as Balena Etcher, Raspberry Pi Imager, Win32 Disk Imager, or `dd`.
3. Insert the microSD card into the ZCU104, connect power, USB UART, and Ethernet,
   then boot the board.
4. Log in with the default first-boot account and change the password when Ubuntu
   asks you to do so:

   ```text
   username: ubuntu
   password: ubuntu
   ```

> AMD's getting-started documentation notes that the ZCU104 has less physical
> memory than the other ZCU10x boards, so avoid heavy desktop usage while building
> and running accelerator examples.

### 2. Install and initialize `xlnx-config` on the board

On the ZCU104 Ubuntu terminal:

```bash
sudo snap install xlnx-config --classic --channel=2.x
xlnx-config.sysinit
```

`xlnx-config` is the tool that discovers installed PAC hardware configurations,
generates the boot image for the selected configuration, and switches the board
to that hardware after reboot.

If `xlnx-config.sysinit` waits for the package manager, let it finish. If it
exits early due to unattended-upgrades or package-lock timing, run it again.

### 3. Copy this repository and the PAC to the board

From your development machine, after `./package_pac.sh` has created
`PAC_container/`, create a transfer archive from the repository root:

```bash
tar -czf zcu104-adder-flow.tar.gz \
  Application libsrc common HLS_library PAC_container README.md
scp zcu104-adder-flow.tar.gz ubuntu@<ZCU104_IP_ADDRESS>:~/
```

On the ZCU104:

```bash
tar -xzf zcu104-adder-flow.tar.gz
```

### 4. Install the PAC where `xlnx-config` can find it

A PAC can be manually installed below `/boot/firmware/xlnx-config/<pac-name>` or
`/usr/local/share/xlnx-config/<pac-name>`. This example uses the SD-card FAT
partition path:

```bash
sudo mkdir -p /boot/firmware/xlnx-config
sudo rm -rf /boot/firmware/xlnx-config/adder_pac
sudo cp -a PAC_container /boot/firmware/xlnx-config/adder_pac
```

Check that `xlnx-config` can see the new configuration:

```bash
xlnx-config -q
```

You should see an entry with PAC configuration name `adder` and a path similar
to:

```text
/boot/firmware/xlnx-config/adder_pac/hwconfig/adder/zcu104
```

### 5. Activate the PAC, then reboot

Activate the hardware configuration:

```bash
sudo xlnx-config -a adder
```

`xlnx-config` should generate a new boot image and tell you that a reboot is
required. Reboot the board:

```bash
sudo reboot now
```

After the ZCU104 comes back, log in again and verify that the configuration is
active:

```bash
xlnx-config -q
```

The active configuration is marked with `*` in the `Act` column.

### 6. Compile the host application on the ZCU104

The FPGA bitstream is now active, but you still need a Linux host executable that
opens the matching `.xclbin`, moves data, launches the kernel, and checks the
result.

Install basic build tools if they are missing:

```bash
sudo apt update
sudo apt install -y build-essential ocl-icd-opencl-dev
```

Then compile the host from this repository on the board:

```bash
cd ~/Application/Adder
./build_host_on_fpga.sh
```

Equivalent Makefile command:

```bash
make host_on_board
```

> Note: `host_on_board` internally uses `HOST_ARCH=x86` only to select the
> native-compiler path in the inherited Vitis Makefile. On the ZCU104, native
> `g++` still produces an Arm `aarch64` executable.

Expected host executable:

```text
Application/Adder/host_adder
```

### 7. Run the application on the FPGA

Run the host executable with the `.xclbin` from the installed PAC:

```bash
./host_adder /boot/firmware/xlnx-config/adder_pac/hwconfig/adder/zcu104/adder.xclbin
```

For the default Adder example, a successful run prints:

```text
TEST PASSED
```

### 8. Deactivate the custom hardware if needed

To return to the default/golden ZCU104 boot assets:

```bash
sudo xlnx-config -d
sudo reboot now
```

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
