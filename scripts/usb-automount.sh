#!/bin/bash
# USAGE: usb-automount.sh DEVICE FILESYSTEM
#   LOG_FILE    is the error/activity log file for shell (eg /home/pi/logs/usbloader.log)
#   MOUNT_DIR   is the full mount folder for device (/media/sda1)
#   DEVICE      is the actual device node at /dev/DEVICE (returned by udev rules %k parameter) (eg sda1)
#   FILESYSTEM  is the FileSystem type returned by rules (returned by udev rules %E{ID_FS_TYPE} or $env{ID_FS_TYPE} (eg vfat)
################################### Variables & functions
source <(curl -sL https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/lib.sh) ; wait

################################### Check for errors + debug code and abort if something isn't right
# 1 = ON / 0 = OFF
DEBUG=0
debug_mode

################################### Options
LOG_FILE="$1"
MOUNT_DIR="$2"

################################### check input parameters
[ "$MOUNT_DIR" ] || fatal "Missing Parameter: MOUNT_DIR"
[ "$DEVICE" ] || fatal "Missing Parameter: DEVICE"
[ "$FILESYSTEM" ] || fatal "Missing Parameter: FILESYSTEM"

################################### check defined log file
if [ -b /dev/"$DEVICE" ]; then
	header "Start usb-automount.sh $(date)"
	success "Valid block device found"
else
	header "[ == Start usb-automount.sh $(date) == ]"
	fatal "No valid partition / block device found, please format a single EXT4/FAT/NTFS partition and retry"
	exit 1
fi

################################### Mount & log
echo >> "$LOG_FILE_AUTOMOUNT"
automount >> "$LOG_FILE_AUTOMOUNT" 2>&1

###################################  Auto start & log
#if [ "$AUTO_START" == "1" ]; then # Do we want to auto-start a new process? 0 - No; 1 - Yes
header "[ == USB Auto start script == ]"
echo >> "$LOG_FILE_AUTOSTART"
autostart >> "$LOG_FILE_AUTOSTART" 2>&1
success "[ == END usb-automount.sh  $(date) == ]"
#fi

################################### Cleanup & exit
exit 0
