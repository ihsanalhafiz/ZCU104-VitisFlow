#!/bin/bash

#functions and globals
VERSION='0.5' # current script version
REDTEXT='\e[31m'
BLUETEXT='\e[34m'
NCTEXT='\e[0m' # No Color

#the files that need to be copied from the Vitis platform into the container
bootFiles=("fsbl.elf" "bl31.elf" "pmufw.elf");
#the valid boards that work with this flow
validBoards=("zcu102" "zcu104" "zcu106" "zcu111" "zcu208" "zcu216");

bifFileName="bootgen.bif"
dtbFileName="system.dtb"
bitstreamFileName="system.bit"

#declare an array to contain all data files
#this is an array because the user can specify
#more than one item
DATAFILES=()

function print_version () {
	echo "Vitis Platform Assets Container (PAC) creation script, version $VERSION";
	exit 0;
}

function print_help () {
	echo -e "usage: $0 [options] \n \
	-c,--container	- Path to directory where the PAC is to be created, including name \n \
	-p,--platform	- Path to Vitis .xpfm file \n \
	-v,--vitis	- Path to the directory containing the Vitis application project (eg, contains build_dir.hw.<platform name>) \n \
	-n,--configname	- The configuration name inside the container \n \
	-b,--board	- Name of the board targer for this configuration \n \
	-d,--data	- (Optional) The complete path (including filename) of an item to include in the data directory \n \
	-x,--xclbin	- (Optional) The complete path (including filename) of an additional .xclbin file to include in the hwconfig directory \n \
	--version - (Optional) Echo the current script version";
}

if [[ $# -eq 0 ]]; then
	print_help;
	exit 0;
fi

while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -p|--platform)
      PLATFILEPATH="$2"
      shift # past argument
      shift # past value
      ;;
	-c|--container)
	  CONTAINERDIR="$2"
      shift # past argument
      shift # past value
      ;;
	-n|--configname)
	  CONFIGNAME="$2"
      shift # past argument
      shift # past value
      ;;	  
	-b|--board)
	  BOARDNAME="$2"
      shift # past argument
      shift # past value
      ;;	 
	-d|--data)	  
	  DATAFILES+=("$2")
      shift # past argument
      shift # past value
      ;;	
	-x|--xclbin)	  
	  XCLBIN+=("$2")
      shift # past argument
      shift # past value
      ;;
	-v|--vitis)	  
	  VITISPATH+=("$2")
      shift # past argument
      shift # past value
      ;;
    -h|--help)
      print_help;
	  exit 0;
	  ;;
    --version)
      print_version;
	  exit 0;
	  ;;
    *)    # unknown option
      echo "ERROR: Invalid argument specified"
	  exit 1;
      ;;
  esac
done

#check if the specified board is in the whitelist
validBoard=0;
for board in ${validBoards[@]}; do
	if [ "$board" == "$BOARDNAME" ]
	then
		validBoard=1;
	fi
done

# Check for missing/invalid required arguments
ERRORLEVEL=0;
if [ ! -v BOARDNAME ]
then
	echo "ERROR: No board name specified."
	ERRORLEVEL=$(expr $ERRORLEVEL + 1);
fi
if [ "$validBoard" -lt "1" ]
then
	echo "ERROR: Unsupported board $BOARDNAME"
	ERRORLEVEL=$(expr $ERRORLEVEL + 1);
fi
if [ ! -v CONTAINERDIR ]
then
	echo "ERROR: No PAC path specified."
	ERRORLEVEL=$(expr $ERRORLEVEL + 1);
fi
if [ ! -v PLATFILEPATH ]
then
	echo "ERROR: No Vitis hardware platform file specified."
	ERRORLEVEL=$(expr $ERRORLEVEL + 1);
fi
if [ ! -v CONFIGNAME ]
then
	echo "ERROR: Configuration name not specified."
	ERRORLEVEL=$(expr $ERRORLEVEL + 1);
fi
if [ ! -v VITISPATH ]
then
	echo "ERROR: Accelerated application location not specified."
	ERRORLEVEL=$(expr $ERRORLEVEL + 1);
fi
if [ "$ERRORLEVEL" -gt "0" ]
then
	exit 1;
fi

echo "Checking for Vitis platform collateral..."

echo "Checking for XPFM file..."
if [ ! -f $PLATFILEPATH ]
then
	echo "ERROR! XPFM not found at $PLATFILEPATH"
	exit 1;
else
	echo "FOUND at $PLATFILEPATH"
fi

echo "Checking for Vitis accelerated application directory..."
if [ ! -d $VITISPATH ]
then
	echo "ERROR! Vitis accelerated application not found at $VITISPATH"
	exit 1;
else
	echo "FOUND at $VITISPATH"
fi

# once the platform path location is confirmed, build the various paths
# for later use
PLATBASEPATH=$(echo ${PLATFILEPATH%/*})
PLATFILENAME=$(echo ${PLATFILEPATH##*/})
PLATNAME=$(echo ${PLATFILENAME%.*})

# determine the container name based on path
CONTAINERNAME=$(echo ${CONTAINERDIR##*/})

# check if some of the subdirectories and files exist
# this is part of the fail early mentality

# check for the sw subdirectory in the platform
echo "Checking for platform firmware directory..."
FIRMWAREDIR="$PLATBASEPATH/sw"
if [ ! -d $FIRMWAREDIR ]
then
	echo "ERROR: platform firmware directory not at $FIRMWAREDIR";
	echo "Is the platform directory structure correct/complete?"
	exit 1;
else
	echo "FOUND at $FIRMWAREDIR"
fi
echo " "
	
# check for the boot directory inside the software directory FIRMWAREDIR="$PLATBASEPATH/sw"
echo "Checking for platform boot collateral..."
BOOTDIR="$FIRMWAREDIR/$PLATNAME/boot"
if [ ! -d $BOOTDIR ]
then
	echo "ERROR: boot collateral directory not at $BOOTDIR";
	echo "Is the platform directory structure correct/complete?"
	exit 1;
else
	echo "FOUND at $BOOTDIR";
fi
echo " "

#check for the hardware configuration inside the accelerated application
echo "Checking for the accelerated application hardware configuration..."
APPHWBUILDDIR=$VITISPATH/build_dir.hw.$PLATNAME/
if [ ! -d $APPHWBUILDDIR ]
then
	echo "ERROR: Hardware build directory missing inside accelerated application $VITISPATH"
	echo "Have you build the hardware for the accelerated application?"
	exit 1;
else
	echo "FOUND at $APPHWBUILDDIR"
fi
echo " "

# start creating the PAC
echo "Building the xlnx-config PAC directory structure...";

# create the full path to the board-specific directory
echo -n "Creating the board directory inside the container..."
if [ ! -d $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME ]
then
	mkdir -p $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME
	echo "DONE"
	echo "Created at $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME"
else
	echo "DIRECTORY EXISTS"
	echo "Found at $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME"
fi
echo "Finished creating container directories"
echo " "

# populate the board-specific directory with files from the Vitis platform
echo "Copying boot files from Vitis platform into the container:"
for file in ${bootFiles[@]}; do
echo -n "Copying file $file..."
if [ -f $PLATBASEPATH/sw/$PLATNAME/boot/$file ]; then
	echo "DONE"
	cp -f $PLATBASEPATH/sw/$PLATNAME/boot/$file $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME
	
else
	echo "ERROR!"
	echo "The file $file does not exist at $PLATBASEPATH/sw/$PLATNAME/boot/"
	
fi
done

echo -n "Copying the device tree dtb file from the Vitis platform into the container..."
if [ -f $PLATBASEPATH/sw/$PLATNAME/boot/$dtbFileName ]; then
	echo "DONE"
	cp -f $PLATBASEPATH/sw/$PLATNAME/boot/$dtbFileName $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME
	
else
	echo "ERROR!"
	echo "The file $dtbFileName does not exist at $PLATBASEPATH/sw/$PLATNAME/xrt/image/"
	
fi
echo " "

echo -n "Copying the XCLBIN file for the Vitis accelerated application..."
shopt -s nullglob
if [[ -e $(echo $APPHWBUILDDIR/*.xclbin) ]]
then
	echo "DONE!"
	cp -f $APPHWBUILDDIR/*.xclbin $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME
else
	echo "ERROR!"
	echo "No XCLBIN file found at $APPHWBUILDDIR."
fi
echo " "

echo -n "Copying the bitstream file ($bitstreamFileName) for the Vitis accelerated application..."
if [ -f $APPHWBUILDDIR/link/int/$bitstreamFileName ]
then
	echo "DONE!"
	cp -f $APPHWBUILDDIR/link/int/$bitstreamFileName $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME
else
	echo "ERROR!"
	echo "No bitstream file found at $APPHWBUILDDIR/link/int/."
fi
echo " " 
####Add the code for copying the system.bit and xclbin from the Accelerated Application area


if [ -v XCLBIN ]
then
	echo -n "Copying additional XCLBIN file $XCLBIN..."
	echo "DONE!"
	
	cp -f $XCLBIN $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME
fi

echo "Finished populating boot files"
echo " "

# create the custom bif file
echo "Creating BootGen .BIF file for $CONFIGNAME/$BOARDNAME..."
echo -n "Checking for existing BIF file at $PLATBASEPATH/sw/$PLATNAME/boot/$bifFileName..."
if [ -f $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME/$bifFileName ]; then
	echo "EXISTS!"
	echo "Removing the existing $bifFileName"
	rm -f $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME/$bifFileName
else
	echo "NOT FOUND!"
fi
echo "Creating BIF file..."
echo "/* ubuntu boot image*/" > $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME/$bifFileName;
echo "the_ROM_image:" >> $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME/$bifFileName;
echo "{" >> $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME/$bifFileName;
echo "  [bootloader, destination_cpu=a53-0] fsbl.elf" >> $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME/$bifFileName;
echo "  [pmufw_image] pmufw.elf" >> $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME/$bifFileName;
echo "  [destination_device=pl] system.bit" >> $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME/$bifFileName;
echo "  [destination_cpu=a53-0, exception_level=el-3, trustzone] bl31.elf" >> $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME/$bifFileName;
echo "  [destination_cpu=a53-0, load=0x00100000] system.dtb" >> $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME/$bifFileName;
echo "  [destination_cpu=a53-0, exception_level=el-2] /usr/lib/u-boot/xilinx_zynqmp_virt/u-boot.elf" >> $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME/$bifFileName;
echo "}" >> $CONTAINERDIR/hwconfig/$CONFIGNAME/$BOARDNAME/$bifFileName;
echo " "

# create the data_sw directory
if [ ${#DATAFILES[@]} -gt "0" ]
then

	echo -n "Creating the SW Data directory inside the container..."
	if [ ! -d $CONTAINERDIR/data/$CONFIGNAME/$BOARDNAME ]
	then
		mkdir -p $CONTAINERDIR/data/$CONFIGNAME/$BOARDNAME
		echo "DONE"
		echo "Created at $CONTAINERDIR/data/$CONFIGNAME/$BOARDNAME"
	else
		echo "DIRECTORY EXISTS"
		echo "Found at $CONTAINERDIR/data/$CONFIGNAME/$BOARDNAME"
	fi
	echo "Finished creating SW Data directory"
	
	echo "Copying SW data file $DATAFILES"
	for data in ${DATAFILES[@]}; do
		cp -f $data $CONTAINERDIR/data/$CONFIGNAME/$BOARDNAME
	done

else
	echo "No SW Data specified, skipping..."
fi
echo " "

# fix up the manifest.yaml file
echo "Updating the manifest.yaml file"
echo "Container: $CONTAINERNAME"
readarray -t configDirs < <(find $CONTAINERDIR/hwconfig -maxdepth 1 -type d -printf '%P\n')
for configDir in ${configDirs[@]}; do
echo "Configuration: $configDir"
	if [ -f "$CONTAINERDIR/hwconfig/$configDir/manifest.yaml" ]
	then
		echo "Removing old manifest.yaml file..."
		rm -f $CONTAINERDIR/hwconfig/$configDir/manifest.yaml
	fi
		
	touch $CONTAINERDIR/hwconfig/$configDir/manifest.yaml
	echo "name: $configDir" >> $CONTAINERDIR/hwconfig/$configDir/manifest.yaml;
	echo "description: Boot assets for the $configDir configuration inside the $CONTAINERNAME container" >> $CONTAINERDIR/hwconfig/$configDir/manifest.yaml;
	echo "revision: 1.0" >> $CONTAINERDIR/hwconfig/$configDir/manifest.yaml;
	echo "assets:" >> $CONTAINERDIR/hwconfig/$configDir/manifest.yaml;
		
	readarray -t boardDirs < <(find $CONTAINERDIR/hwconfig/$configDir -maxdepth 1 -type d -printf '%P\n')
	for boardDir in ${boardDirs[@]}; do
		echo "Board: $boardDir"
		echo -e "    $boardDir: $boardDir" >> $CONTAINERDIR/hwconfig/$configDir/manifest.yaml;
	done
	
done
echo " "

echo "########################################################"
echo " "
echo "Manifest updated at $configDir/manifest.yaml"
echo "Please review and update description & revision metadata"

echo " "
echo "All finished!"