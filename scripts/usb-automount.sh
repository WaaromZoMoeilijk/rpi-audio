#!/bin/bash
# USAGE: usb-automount.sh DEVICE FILESYSTEM
#   LOG_FILE    is the error/activity log file for shell (eg /home/pi/logs/usbloader.log)
#   MOUNT_DIR   is the full mount folder for device (/media/sda1)
#   DEVICE      is the actual device node at /dev/DEVICE (returned by udev rules %k parameter) (eg sda1)
#   FILESYSTEM  is the FileSystem type returned by rules (returned by udev rules %E{ID_FS_TYPE} or $env{ID_FS_TYPE} (eg vfat)
#
# In case the process of mounting takes too long for udev
# we call this script from /home/pi/scripts/usb-initloader.sh
# then fork out to speciality scripts
#
################################### Variables & functions
source <(curl -sL https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/lib.sh) ; wait

################################### Check for errors + debug code and abort if something isn't right
# 1 = ON | 0 = OFF
DEBUG=0
debug_mode

################################### Options
LOG_FILE="$1"
MOUNT_DIR="$2"
DEVICE="$3"  # USB device name (from kernel parameter passed from rule)
FILESYSTEM="$4"
AUTO_START="$5" # Do we want to auto-start a new process? 0 - No; 1 - Yes

################################### check input parameters
[ "$MOUNT_DIR" ] || fatal "Missing Parameter: MOUNT_DIR"
[ "$DEVICE" ] || fatal "Missing Parameter: DEVICE"
[ "$FILESYSTEM" ] || fatal "Missing Parameter: FILESYSTEM"

################################### check defined log file
if [ -b /dev/"$DEVICE" ]; then
    echo "Valid block device found"
else
    echo "No valid partition / block device found, please format a single vfat partition and retry"
    exit 1
fi

if [ -z "$LOG_FILE" ]; then
    echo "No log file present"
    exit 1
fi

################################### Mount & log
automount >> "$LOG_FILE" 2>&1

###################################  Auto start & log
if [ "$AUTO_START" == "1" ]; then
	echo ; echo -e "|" "${IBlue} --- USB Auto start script --- ${Color_Off} |" >&2 ; echo
	autostart >> "$LOG_FILE" 2>&1
	echo "###########  END usb-automount.sh  $(date)   ############"
fi

################################### Cleanup & exit

exit 0
