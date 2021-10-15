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
DEBUG=0
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

	if [ -d /mnt/"$DEVICE" ]; then
		echo ; echo -e "|" "${IRed}Directory /mnt/$DEVICE still exists, removing${Color_Off} |" >&2
		echo
		umount -l "/mnt/$DEVICE" | sleep 1
		rmdir "/mnt/$DEVICE"
		if [ $? -eq 0 ]; then
			echo ; echo -e "|" "${IGreen}Removed directory /mnt/$DEVICE${Color_Off} |" >&2
		else
			echo ; echo -e "|" "${IRed}Directory removal of /mnt/$DEVICE failed${Color_Off} |" >&2
		fi		
	else
		echo ; echo -e "|" "${IGreen}Directory /mnt/$DEVICE not present${Color_Off} |" >&2
	fi
}

################################### Unmount & log
autounload >> "$LOG_FILE" 2>&1

################################### End script
if [[ "$AUTO_END" == "1" ]]; then
	echo ; echo -e "|" "${IBlue} --- USB Auto end script --- ${Color_Off} |" >&2 ; echo
	echo "No commands setup for the auto end script"
fi

################################### Cleanup & exit

exit 0
