#!/bin/bash
# Called from {GITDIR}/scripts/usb-initloader.sh
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
################################### Variables & functions
source <(curl -sL https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/lib.sh)

################################### Check for errors + debug code and abort if something isn't right
debug_mode() {
if [ "$DEBUG" -eq 1 ]
then
    set -ex
fi
}
# 1 = ON | 0 = OFF
DEBUG=1
debug_mode

################################### Storage
LOG_FILE="$1"
MOUNT_DIR="$2"
DEVICE="$3"  # USB device name (from kernel parameter passed from rule)
AUTO_END="$4"  # Set to 0 if not wanting to shutdown pi, 1 otherwise
USER='dietpi'
GITDIR='/opt/rpi-audio'

################################### check for defined log file
if [ -z "$LOG_FILE" ]; then
    echo ; echo -e "|" "${IRed}No log file${Color_Off} |" >&2
    exit 1
fi

################################### Functions
autounload() {
	echo ; echo -e "|" "${IBlue} --- USB UnLoader --- ${Color_Off} |" >&2 ; echo    

    if [ -z "$MOUNT_DIR" ]; then
	     echo ; echo -e "|" "${IRed}Failed to supply Mount Dir parameter${Color_Off} |" >&2
        exit 1
    fi

    if [ -z "$DEVICE" ]; then
	     echo ; echo -e "|" "${IRed}Failed to supply DEVICE parameter${Color_Off} |" >&2
        exit 1
    fi

    # test that this device has disappeared from mounted devices
    device_mounted=$(grep -q "$DEV" /etc/mtab)
    if [ "$device_mounted" ]; then
         echo ; echo -e "|" "${IRed}/dev/$DEVICE failed to Un-Mount, forcing umount -l${Color_Off} |" >&2
	 	umount -l "/dev/$DEVICE"
    		#exit 1
    else
         echo ; echo -e "|" "${IGreen}/dev/$DEVICE successfully Un-Mounted${Color_Off} |" >&2
    fi
}

################################### Unmount & log
autounload >> "$LOG_FILE" 2>&1

################################### End script
if [[ "$AUTO_END" == "1" ]]; then
	echo ; echo -e "|" "${IBlue} --- USB Auto end script --- ${Color_Off} |" >&2 ; echo
	# command
fi

################################### Cleanup & exit

exit 0
