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
source /opt/rpi-audio/lib.sh

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
	echo "###########  Start usb-automount.sh  $(date)   ############"
	echo ; success "Valid block device found"
else
	echo "###########  Start usb-automount.sh  $(date)   ############"
	echo ; fatal "No valid partition / block device found, please format a single vfat partition and retry"
	exit 1
fi

if [ -z "$LOG_FILE" ]; then 
	echo ; fatal "No log file present"
	exit 1
fi

#################################### Auto Start Function
autostart() {
	echo ; echo "--- USB Auto Start Program --- $DATE" ; echo
	DEV=$(echo "$DEVICE" | cut -c -3)
	# Check # of partitions
        if [[ $(grep -c "$DEV"'[0-9]' /proc/partitions) -gt 1 ]]; then
	        echo -e "${IRed}More then 1 parition detected, please format your drive and create a single FAT32/NTFS/EXT partition and try again${Color_Off}" >&2
		exit 1
        elif [[ $(grep -c "$DEV"'[0-9]' /proc/partitions) -eq 0 ]]; then
		echo -e "${IRed}No parition detected, please format your drive and create a single FAT32/NTFS/EXT partition and try again${Color_Off}" >&2
		exit 1
        elif [[ $(grep -c "$DEV"'[0-9]' /proc/partitions) -eq 1 ]]; then
                echo -e "${IGreen}1 partition detected, checking if its been used before${Color_Off}" >&2
	        # Check if drive is empty
	        if [ -z "$(ls -I '.Trash*' -A "$MOUNT_DIR/$DEVICE")" ] ; then
        	        # Empty
			echo
			mkdir -p "$MOUNT_DIR/$DEVICE/Recordings" && echo -e "${IGreen}Created $MOUNT_DIR/$DEVICE/Recordings${Color_Off}" >&2 || echo -e "${IRed}Failed to create $MOUNT_DIR/$DEVICE/Recordings${Color_Off}" >&2
			echo "$MOUNT_DIR/$DEVICE $DEVID $DATE" >> "$MOUNT_DIR/$DEVICE/Recordings/.active" && echo -e "${IGreen}Written device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active${Color_Off}" >&2 || echo -e "${IRed}Failed to write device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active${Color_Off}" >&2
			chown -R "$USER":"$USER" "$MOUNT_DIR/$DEVICE" && echo -e "${IGreen}Set permissions on $MOUNT_DIR/$DEVICE${Color_Off}" >&2 || echo -e "${IRed}Set permissions on $MOUNT_DIR/$DEVICE failed${Color_Off}" >&2
			# Temporary export GPG keys to storage device.
			mkdir -p "$MOUNT_DIR/$DEVICE/DevGnupg" && echo -e "${IGreen}Created temp dev gnupg folder${Color_Off}" >&2 || echo -e "${IRed}Failed to create temp dev gnupg folder${Color_Off}" >&2
			gpg1 --export-ownertrust > "$MOUNT_DIR/$DEVICE/DevGnupg/otrust.txt"
			gpg1 -a --export-secret-keys > "$MOUNT_DIR/$DEVICE/DevGnupg/privatekey.asc"
			gpg1 -a --export > "$MOUNT_DIR/$DEVICE/DevGnupg/publickey.asc"
	        else
        	        # Not Empty
			# Check if .active resides in Recordings/
			if [ -f "$MOUNT_DIR/$DEVICE/Recordings/.active" ]; then
				# Yes
				echo ; echo -e "${IYellow}Device has already been setup previously, importing${Color_Off}" >&2 
                           	echo "$MOUNT_DIR/$DEVICE $DEVID $DATE" >> "$MOUNT_DIR/$DEVICE/Recordings/.active" && echo -e "${IGreen}Written device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active${Color_Off}" >&2 || echo -e "${IRed}Failed to write device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active${Color_Off}" >&2
				chown -R "$USER":"$USER" "$MOUNT_DIR/$DEVICE" && echo -e "${IGreen}Set permissions on $MOUNT_DIR/$DEVICE${Color_Off}" >&2 || echo -e "${IRed}Set permissions on $MOUNT_DIR/$DEVICE failed${Color_Off}" >&2
				if [ -z "$(ls -A MOUNT_DIR/$DEVICE/DevGnupg)" ]; then
					echo "Temporary Dev GPG key folder is empty, copying"
					# Temporary export GPG keys to storage device.
					mkdir -p "$MOUNT_DIR/$DEVICE/DevGnupg" && echo -e "${IGreen}Created temp dev gnupg folder${Color_Off}" >&2 || echo -e "${IRed}Failed to create temp dev gnupg folder${Color_Off}" >&2
					gpg1 --export-ownertrust > "$MOUNT_DIR/$DEVICE/DevGnupg/otrust.txt"
					gpg1 -a --export-secret-keys > "$MOUNT_DIR/$DEVICE/DevGnupg/privatekey.asc"
					gpg1 -a --export > "$MOUNT_DIR/$DEVICE/DevGnupg/publickey.asc"
				else
					echo -e "${IYellow}Temporary Dev GPG key folder is populated already, skipping${Color_Off}" >&2 
				fi
			else
				# No
				echo
				mkdir -p "$MOUNT_DIR/$DEVICE/Recordings" && echo -e "${IGreen}Created $MOUNT_DIR/$DEVICE/Recordings${Color_Off}" >&2 || echo -e "${IRed}Failed to create $MOUNT_DIR/$DEVICE/Recordings${Color_Off}" >&2
				echo "$MOUNT_DIR/$DEVICE $DEVID $DATE" >> "$MOUNT_DIR/$DEVICE/Recordings/.active" && echo -e "${IGreen}Written device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active${Color_Off}" >&2 || echo -e "${IRed}Failed to write device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active${Color_Off}" >&2
				chown -R "$USER":"$USER" "$MOUNT_DIR/$DEVICE" && echo -e "${IGreen}Set permissions on $MOUNT_DIR/$DEVICE${Color_Off}" >&2 || echo -e "${IRed}Set permissions on $MOUNT_DIR/$DEVICE failed${Color_Off}" >&2
				# Temporary export GPG keys to storage device.
				mkdir -p "$MOUNT_DIR/$DEVICE/DevGnupg" && echo -e "${IGreen}Created temp dev gnupg folder${Color_Off}" >&2 || echo -e "${IRed}Failed to create temp dev gnupg folder${Color_Off}" >&2
				gpg1 --export-ownertrust > "$MOUNT_DIR/$DEVICE/DevGnupg/otrust.txt"
				gpg1 -a --export-secret-keys > "$MOUNT_DIR/$DEVICE/DevGnupg/privatekey.asc"
				gpg1 -a --export > "$MOUNT_DIR/$DEVICE/DevGnupg/publickey.asc"
                        fi
                fi
        fi
        # Start audio recording
        echo >> "$LOG_FILE_AUDIO" ; echo "$(date)" >> "$LOG_FILE_AUDIO"
        "$GITDIR/scripts/audio.sh" >> "$LOG_FILE_AUDIO" 2>&1
}

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
