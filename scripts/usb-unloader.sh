#!/bin/bash
# Called from {SCRIPT_DIR}/usb-initloader.sh
#
# USAGE: usb-automount.sh DEVICE FILESYSTEM
#   LOG_FILE    is the error/activity log file for shell (eg /home/pi/logs/usbloader.log)
#   MOUNT_DIR   is the full mount folder for device (/media)
#   DEVICE      is the actual device node at /dev/DEVICE (returned by udev rules %k parameter) (eg sda1)
#
# UnMounts usb device on /media/<device>
# Logs changes to /var/log/syslog and local log folder
# use tail /var/log/syslog to look at latest events in log
#
#####################
# Debug mode
debug_mode() {
if [ "$DEBUG" -eq 1 ]
then
    set -ex
fi
}

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=1
debug_mode

LOG_FILE="$1"
MOUNT_DIR="$2"
DEVICE="$3"  # USB device name (from kernel parameter passed from rule)
AUTO_END="$4"  # Set to 0 if not wanting to shutdown pi, 1 otherwise

# check for defined log file
if [ -z "$LOG_FILE" ]; then
    exit 1
fi

# Functions:
autounload() {
    dt=$(date '+%Y-%m-%d %H:%M:%S')
    echo "--- USB UnLoader --- $dt"

    if [ -z "$MOUNT_DIR" ]; then
        echo "Failed to supply Mount Dir parameter"
        exit 1
    fi
    if [ -z "$DEVICE" ]; then
        echo "Failed to supply DEVICE parameter"
        exit 1
    fi

    # Unmount device
    sudo umount "/dev/$DEVICE"

    # Wait for a second to make sure async  umount has finished
    sleep 2

    # Remove folder after unmount
    sudo rmdir "$MOUNT_DIR/$DEVICE" && echo "$MOUNT_DIR/$DEVICE folder removed"

    # test that this device has disappeared from mounted devices
    device_mounted=$(grep "$DEVICE" /etc/mtab)
    if [ "$device_mounted" ]; then
        echo "/dev/$DEVICE failed to Un-Mount, forcing umount -l"
	sudo umount -l "/dev/$DEVICE"
        #exit 1
    else
	echo "/dev/$DEVICE successfully Un-Mounted"
    fi
}

autounload >> "$LOG_FILE" 2>&1

# kill auto-start process and shutdown
if [[ "$AUTO_END" == "1" ]]; then
	echo ; echo "--- USB Auto end script --- $dt" ; echo
fi
