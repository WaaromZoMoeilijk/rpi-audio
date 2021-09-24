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

################################### Variables & functions
source <(curl -sL https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/lib.sh)

################################### Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=1
debug_mode

################################### Options
LOG_FILE="$1"
MOUNT_DIR="$2"
DEVICE="$3"  # USB device name (from kernel parameter passed from rule)
FILESYSTEM="$4"
AUTO_START="$5" # Do we want to auto-start a new process? 0 - No; 1 - Yes

################################### check defined log file
if [ -z "$LOG_FILE" ]; then
    exit 1
fi

################################### Define parameters for auto-start program
if [ "$AUTO_START" == "1" ]; then
	echo "vars"
fi

################################### Functions:
automount() {

    echo ; echo "--- USB Auto Mount --- $DATE" ; echo

    # check input parameters
    [ "$MOUNT_DIR" ] || fatal "Missing Parameter: MOUNT_DIR"
    [ "$DEVICE" ] || fatal "Missing Parameter: DEVICE"
    [ "$FILESYSTEM" ] || fatal "Missing Parameter: FILESYSTEM"

    # Allow time for device to be added
    sleep 2

    is_mounted "$DEVICE" && fatal "seems /dev/$DEVICE is already mounted"

    # test mountpoint - it shouldn't exist
    [ -e "$MOUNT_DIR/$DEVICE" ] && fatal "seems mountpoint $MOUNT_DIR/$DEVICE already exists"

    # make the mountpoint
    mkdir "$MOUNT_DIR/$DEVICE"

    # make sure the pi user owns this folder
    chown -R dietpi:dietpi "$MOUNT_DIR/$DEVICE"

    # mount the device base on USB file system
    case "$FILESYSTEM" in

        # most common file system for USB sticks
        vfat)  systemd-mount -t vfat -o utf8,uid=dietpi,gid=dietpi "/dev/$DEVICE" "$MOUNT_DIR/$DEVICE" && echo "Successfully mounted VFAT"
              ;;

        # use locale setting for ntfs
        ntfs)  systemd-mount -t auto -o uid=dietpi,gid=dietpi,locale=en_US.UTF-8 "/dev/$DEVICE" "$MOUNT_DIR/$DEVICE" && echo "Successfully mounted NTFS"
              ;;

        # ext2/3/4
        ext*)  systemd-mount -t auto -o sync,noatime "/dev/$DEVICE" "$MOUNT_DIR/$DEVICE" && echo "Successfully mounted EXT"
              ;;
    esac

	is_mounted "$DEVICE" || fatal "Failed to Mount $MOUNT_DIR/$DEVICE"
	echo ; echo "SUCCESS: /dev/$DEVICE mounted as $MOUNT_DIR/$DEVICE" ; echo
}

#################################### Auto Start Function
autostart() {
	echo ; echo "--- USB Auto Start Program --- $DATE" ; echo
	DEV=$(echo "$DEVICE" | cut -c -3)
	# Check # of partitions
        if [[ $(grep -c "$DEV"'[0-9]' /proc/partitions) -gt 1 ]]; then
	        echo "More then 1 parition detected, please format your drive and create a single FAT32 partition and try again"
		exit 1

        elif [[ $(grep -c "$DEV"'[0-9]' /proc/partitions) -eq 1 ]]; then
                echo "1 partition detected, checking if its been used before"
	        # Check if drive is empty
	        if [ -z "$(ls -A "$MOUNT_DIR/$DEVICE")" ] ; then
        	        # Empty
                	mkdir -p "$MOUNT_DIR/$DEVICE/Recordings" && echo "$DEVID $DATE" > "$MOUNT_DIR/$DEVICE/Recordings/.active" && echo "Created Recordings folder on the external drive"
			chown -R dietpi:dietpi "$MOUNT_DIR/$DEVICE" && echo "Set permissions on $MOUNT_DIR/$DEVICE"
	        else
        	        # Not Empty
			if [ -z "$(ls "$MOUNT_DIR/$DEVICE/Recordings/.active")" ]; then
				echo "Device has already been setup previously, importing"
			else
                                # Stop here or create a folder "Recordings" in the existing media root folder
				# exit 1
				# echo "It seems this drive contains data, please format as FAT32 and try again"
	                        mkdir -p "$MOUNT_DIR/$DEVICE/Recordings" && touch "$MOUNT_DIR/$DEVICE/Recordings/.active" && echo "Recordings folder on the external drive exists, reusing it now"
			fi
	        fi
	fi
}
################################### Mount & log
automount >> "$LOG_FILE" 2>&1

###################################  Auto start & log
if [ "$AUTO_START" == "1" ]; then
    autostart >> "$LOG_FILE" 2>&1
fi

################################### Cleanup & exit

exit 0
