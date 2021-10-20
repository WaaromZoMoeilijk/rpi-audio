#!/bin/bash
################################### Folders
CONFIG="/boot/config.txt"
GITDIR="/opt/rpi-audio"
HOME="/home/admin"
LOCALSTORAGE="/Recordings"
SCRIPT_DIR="$GITDIR/scripts"
LOG_DIR="/var/log"
LOG_FILE="$LOG_DIR/audio-usb-automount.log"
LOG_FILE_AUDIO="$LOG_DIR/audio-recording.log"
LOG_FILE_INSTALL="$LOG_DIR/audio-install.log"
MOUNT_DIR=/mnt # Mount folder (sda1 will be added underneath this)
################################### System
USER="dietpi"
USERNAME="dietpi"
#PASSWORD=$(whiptail --passwordbox "Please enter the password for the new user $USERNAME" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
ROOTDRIVE=$(ls -la /dev/disk/by-partuuid/ | grep "$(cat /etc/fstab | grep ' / ' | awk '{print $1}' | sed 's|PARTUUID=||g')" | awk '{print $11}' | sed "s|../../||g" | sed 's/[0-9]*//g')
DEV=$(lshw -short -c disk | grep -v "$ROOTDRIVE" | awk '{print $2}' | sed 's|path||g' | sed -e '/^$/d')
CHECKDRIVESIZE=$(lshw -short -c disk | grep -v "$ROOTDRIVE" | tail -n+3 | awk '{print $2,$4}')
DEVID=$(ls -la /dev/disk/by-id/ | grep "$DEV" | grep -v 'part' | awk '{print $9}' | sed 's|:0||g')
BLOCKSIZE=$(blockdev --getbsz "$DEV")
USEP=$(df -h | grep "$DEV" | awk '{ print $5 }' | cut -d'%' -f1)
LOCALSTORAGEUSED=$(df -Ph -BM "$LOCALSTORAGE" | tail -1 | awk '{print $4}' | sed 's|M||g')
################################### Opusenc
TITLE=$(cat /etc/hostname)
ARTIST="RaspberryPI"
ALBUM="N/a"
GENRE="Recording"
################################### GPG
GPG_RECIPIENT="recorder@waaromzomoeilijk.nl"
################################### Network
WANIP4=$(curl -s -k -m 5 https://ipv4bot.whatismyipaddress.com)
GATEWAY=$(ip route | grep default | awk '{print $3}')
IFACE=$(ip r | grep "default via" | awk '{print $5}')
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
################################### Links
ISSUES="https://github.com/WaaromZoMoeilijk/rpi-audio/issues"
REPO="https://github.com/WaaromZoMoeilijk/rpi-audio" 
################################### Misc
DATE=$(date '+%Y-%m-%d - %H:%M:%S')
NAMEDATE=$(date '+%Y-%m-%d_%H:%M:%S')
FILEDATE=$(date +%Y-%m-%d_%H:%M:%S)
UFWSTATUS=$(/usr/sbin/ufw status)
################################### Storage
line_count=$(echo -n "$OUTPUT" | grep -c '^')
OUTPUT=$(find /mnt -iname '.active' | sed 's|/.active||g') # $1 Process Id
AUTO_START_FINISH=1 # Set to 0 if false; 1 if true
################################### Audio
CARD=$(arecord -l | grep -m 1 'USB Microphone\|USB\|usb\|Usb\|Microphone\|MICROPHONE\|microphone\|mic\|Mic\|MIC' | awk '{print $2}' | sed 's|:||g')
################################### Functions
is_root() {
    if [[ "$EUID" -ne 0 ]]
    then
        return 1
    else
        return 0
    fi
}
###################################
root_check() {
if ! is_root
then
    msg_box "Failed, script needs sudo permission"
    exit 1
fi
}
###################################
debug_mode() {
if [ "$DEBUG" -eq 1 ]
then
    set -ex
fi
}
###################################
is_mounted() {
    grep -q "$1" /etc/mtab
}
################################### easy colored output
success() {
    echo ; echo -e "${IGreen} $* ${Color_Off}" >&2 ; echo
}

warning() {
    echo ; echo -e "${IYellow} $* ${Color_Off}" >&2 ; echo
}

error() {
    echo ; echo -e "${IRed} $* ${Color_Off}" >&2 ; echo
}

header() {
	echo ; echo -e "${IBlue} $* ${Color_Off}" >&2 ; echo 
}

fatal() {
	echo ; echo -e "${IRed} $* ${Color_Off}" >&2 ; echo
	exit 1
}
################################### Spinner during long commands
spinner() {
    #printf '['
    while ps "$!" > /dev/null; do
        echo -n '⣾⣽⣻'
        sleep '.7'
    done
    #echo ']'
}
###################################
apt_install() {
    apt-get install -y -qq -o=Dpkg::Use-Pty=0 && echo ; echo -e "|" "${IGreen}Packages install done${Color_Off} |" >&2 || echo -e "|" "${IRed}Packages install - Failed${Color_Off} |" >&2
}
###################################
apt_update() {
    apt-get update -qq -o=Dpkg::Use-Pty=0 && echo ; echo "Packages update done" || echo "Packages update - Failed"
}
###################################
apt_upgrade() {
    sudo -E apt-get -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" full-upgrade -y -qq && echo ; echo "Packages upgrade done" || echo "Packages upgrade - Failed"
}
###################################
apt_autoremove() {
    apt-get autopurge -y -qq && echo ; echo "Packages autopurge done" || echo "Packages autopurge - Failed"
}
###################################
apt_autoclean() {
    apt-get -y autoclean -qq && echo ; echo "Packages clean done" || echo "Packages clean - Failed"
}
###################################
install_if_not() {
if ! dpkg-query -W -f='${Status}' "${1}" | grep -q "ok installed"; then
    apt update -q4 & spinner_loading && RUNLEVEL=1 apt install "${1}" -y
fi
}
###################################
is_installed() {
if ! dpkg-query -W -f='${Status}' "${1}" | grep -q "ok installed"; then
	warning "${1} is not installed"
else
	success "${1} is installed"
fi
}
################################### Define parameters for auto-start program
automount() {
    header "USB Auto Mount$DATE"; echo

    # Allow time for device to be added
    sleep 2

    is_mounted "$DEVICE" && fatal "seems /dev/$DEVICE is already mounted"

    # test mountpoint - it shouldn't exist
    [ -e "$MOUNT_DIR/$DEVICE" ] && fatal "seems mountpoint $MOUNT_DIR/$DEVICE already exists"

    # make the mountpoint
    mkdir "$MOUNT_DIR/$DEVICE" && success "Mountpoint $MOUNT_DIR/$DEVICE created" || fatal "Mountpoint $MOUNT_DIR/$DEVICE creation failed"

    # make sure the user owns this folder
    chown -R "$USER":"$USER" "$MOUNT_DIR/$DEVICE" && success "Chown $USER:$USER on $MOUNT_DIR/$DEVICE set" || fatal "Chown $USER:$USER on $MOUNT_DIR/$DEVICE failed"

    # mount the device base on USB file system
    case "$FILESYSTEM" in

        # most common file system for USB sticks
        vfat)  systemd-mount -t vfat -o utf8,uid="$USER",gid="$USER" "/dev/$DEVICE" "$MOUNT_DIR/$DEVICE" && success "Successfully mounted /dev/$DEVICE on $MOUNT_DIR/$DEVICE with fs: VFAT" || fatal "Failed mounting VFAT parition"
              ;;

        # use locale setting for ntfs
        ntfs)  systemd-mount -t auto -o uid="$USER",gid="$USER",locale=en_US.UTF-8 "/dev/$DEVICE" "$MOUNT_DIR/$DEVICE" && success "Successfully mounted /dev/$DEVICE on $MOUNT_DIR/$DEVICE with fs: NTFS" || fatal "Failed mounting NTFS partition"
              ;;

        # ext2/3/4
        ext*)  systemd-mount -t auto -o sync,noatime "/dev/$DEVICE" "$MOUNT_DIR/$DEVICE" && success "Successfully mounted /dev/$DEVICE on $MOUNT_DIR/$DEVICE with fs: EXT" || fatal "Failed mounting EXT partition"
 	      ;;	
     esac
	sleep 3
	is_mounted "$DEVICE" && success "Mount OK" || fatal "Sumtin wong sir"
}

#################################### Auto Start Function
autostart() {
header "USB Auto Start Program"
DEV=$(echo "$DEVICE" | cut -c -3)
# Check # of partitions
if [[ $(grep -c "$DEV"'[0-9]' /proc/partitions) -gt 1 ]]; then
	error "More then 1 parition detected, please format your drive and create a single FAT32/NTFS/EXT partition and try again"
	exit 1
elif [[ $(grep -c "$DEV"'[0-9]' /proc/partitions) -eq 0 ]]; then
	error "No parition detected, please format your drive and create a single FAT32/NTFS/EXT partition and try again"
	exit 1
elif [[ $(grep -c "$DEV"'[0-9]' /proc/partitions) -eq 1 ]]; then
	success "1 partition detected, checking if its been used before"
	# Check if drive is empty
	if [ -f "$(ls -I '.Trash*' -A "$MOUNT_DIR/$DEVICE")" ]; then
		# Empty
		echo ; echo "EMPTY"
		mkdir -p "$MOUNT_DIR/$DEVICE/Recordings" && success "Created $MOUNT_DIR/$DEVICE/Recordings" || error "Failed to create $MOUNT_DIR/$DEVICE/Recordings"
		echo "$MOUNT_DIR/$DEVICE $DEVID $DATE" >> "$MOUNT_DIR/$DEVICE/Recordings/.active" && success "Written device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active" || error "Failed to write device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active"
		chown -R "$USER":"$USER" "$MOUNT_DIR/$DEVICE" && success "Set permissions on $MOUNT_DIR/$DEVICE" || error "Set permissions on $MOUNT_DIR/$DEVICE failed"
		# Temporary export GPG keys to storage device.
		mkdir -p "$MOUNT_DIR/$DEVICE/DevGnupg" && success "Created temp dev gnupg folder" || error "Failed to create temp dev gnupg folder"
		gpg1 --export-ownertrust > "$MOUNT_DIR/$DEVICE/DevGnupg/otrust.txt"
		gpg1 -a --export-secret-keys > "$MOUNT_DIR/$DEVICE/DevGnupg/privatekey.asc"
		gpg1 -a --export > "$MOUNT_DIR/$DEVICE/DevGnupg/publickey.asc"
	else
		# Not Empty
		# Check if .active resides in Recordings/
		if [ -f "$MOUNT_DIR/$DEVICE/Recordings/.active" ]; then
			# Yes
			warning "NOT EMPTY - Device has already been setup previously, importing" 
			echo "$MOUNT_DIR/$DEVICE $DEVID $DATE" >> "$MOUNT_DIR/$DEVICE/Recordings/.active" && success "Written device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active" || error "Failed to write device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active"
			chown -R "$USER":"$USER" "$MOUNT_DIR/$DEVICE" && success "Set permissions on $MOUNT_DIR/$DEVICE" || error "Set permissions on $MOUNT_DIR/$DEVICE failed"
			if [ -f "$(ls -A "$MOUNT_DIR/$DEVICE"/DevGnupg)" ]; then
				echo "Temporary Dev GPG key folder is empty, copying"
				# Temporary export GPG keys to storage device.
				mkdir -p "$MOUNT_DIR/$DEVICE/DevGnupg" && success "Created temp dev gnupg folder" || error "Failed to create temp dev gnupg folder"
				gpg1 --export-ownertrust > "$MOUNT_DIR/$DEVICE/DevGnupg/otrust.txt"
				gpg1 -a --export-secret-keys > "$MOUNT_DIR/$DEVICE/DevGnupg/privatekey.asc"
				gpg1 -a --export > "$MOUNT_DIR/$DEVICE/DevGnupg/publickey.asc"
			else
				warning "Temporary Dev GPG key folder is populated already, skipping" 
			fi
		else
			# No
			echo
			mkdir -p "$MOUNT_DIR/$DEVICE/Recordings" && success "Created $MOUNT_DIR/$DEVICE/Recordings" || error "Failed to create $MOUNT_DIR/$DEVICE/Recordings"
			echo "$MOUNT_DIR/$DEVICE $DEVID $DATE" >> "$MOUNT_DIR/$DEVICE/Recordings/.active" && success "Written device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active" || error "Failed to write device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active"
			chown -R "$USER":"$USER" "$MOUNT_DIR/$DEVICE" && success "Set permissions on $MOUNT_DIR/$DEVICE" || error "Set permissions on $MOUNT_DIR/$DEVICE failed"
			# Temporary export GPG keys to storage device.
			mkdir -p "$MOUNT_DIR/$DEVICE/DevGnupg" && success "Created temp dev gnupg folder" || error "Failed to create temp dev gnupg folder"
			gpg1 --export-ownertrust > "$MOUNT_DIR/$DEVICE/DevGnupg/otrust.txt"
			gpg1 -a --export-secret-keys > "$MOUNT_DIR/$DEVICE/DevGnupg/privatekey.asc"
			gpg1 -a --export > "$MOUNT_DIR/$DEVICE/DevGnupg/publickey.asc"
		fi
	fi
fi
# Start audio recording
header "Start recording" 
echo >> "$LOG_FILE_AUDIO" ; echo "$(date)" >> "$LOG_FILE_AUDIO"
"$GITDIR/scripts/audio.sh" >> "$LOG_FILE_AUDIO" 2>&1
}

################################### usb-unloader.sh
autounload() {
	header "USB UnLoader"   

	if [ -z "$MOUNT_DIR" ]; then
	     error "Failed to supply Mount Dir parameter"
	exit 1
	fi

	if [ -z "$DEVICE" ]; then
	     error "Failed to supply DEVICE parameter"
	exit 1
	fi

	if [ -d /mnt/"$DEVICE" ]; then
		error "Directory /mnt/$DEVICE still exists, removing"
		echo
		umount -l "/mnt/$DEVICE" | sleep 1
		rmdir "/mnt/$DEVICE"
		if [ $? -eq 0 ]; then
			success "Removed directory /mnt/$DEVICE"
		else
			error "Directory removal of /mnt/$DEVICE failed"
		fi		
	else
		success "Directory /mnt/$DEVICE not present"
	fi
}

###################################
print_text_in_color() {
printf "%b%s%b\n" "$1" "$2" "$Color_Off"
}
# Reset
Color_Off='\e[0m'       # Text Reset
# Regular Colors
Black='\e[0;30m'        # Black
Red='\e[0;31m'          # Red
Green='\e[0;32m'        # Green
Yellow='\e[0;33m'       # Yellow
Blue='\e[0;34m'         # Blue
Purple='\e[0;35m'       # Purple
Cyan='\e[0;36m'         # Cyan
White='\e[0;37m'        # White
# Bold
BBlack='\e[1;30m'       # Black
BRed='\e[1;31m'         # Red
BGreen='\e[1;32m'       # Green
BYellow='\e[1;33m'      # Yellow
BBlue='\e[1;34m'        # Blue
BPurple='\e[1;35m'      # Purple
BCyan='\e[1;36m'        # Cyan
BWhite='\e[1;37m'       # White
# Underline
UBlack='\e[4;30m'       # Black
URed='\e[4;31m'         # Red
UGreen='\e[4;32m'       # Green
UYellow='\e[4;33m'      # Yellow
UBlue='\e[4;34m'        # Blue
UPurple='\e[4;35m'      # Purple
UCyan='\e[4;36m'        # Cyan
UWhite='\e[4;37m'       # White
# Background
On_Black='\e[40m'       # Black
On_Red='\e[41m'         # Red
On_Green='\e[42m'       # Green
On_Yellow='\e[43m'      # Yellow
On_Blue='\e[44m'        # Blue
On_Purple='\e[45m'      # Purple
On_Cyan='\e[46m'        # Cyan
On_White='\e[47m'       # White
# High Intensity
IBlack='\e[0;90m'       # Black
IRed='\e[0;91m'         # Red
IGreen='\e[0;92m'       # Green
IYellow='\e[0;93m'      # Yellow
IBlue='\e[0;94m'        # Blue
IPurple='\e[0;95m'      # Purple
ICyan='\e[0;96m'        # Cyan
IWhite='\e[0;97m'       # White
# Bold High Intensity
BIBlack='\e[1;90m'      # Black
BIRed='\e[1;91m'        # Red
BIGreen='\e[1;92m'      # Green
BIYellow='\e[1;93m'     # Yellow
BIBlue='\e[1;94m'       # Blue
BIPurple='\e[1;95m'     # Purple
BICyan='\e[1;96m'       # Cyan
BIWhite='\e[1;97m'      # White
# High Intensity backgrounds
On_IBlack='\e[0;100m'   # Black
On_IRed='\e[0;101m'     # Red
On_IGreen='\e[0;102m'   # Green
On_IYellow='\e[0;103m'  # Yellow
On_IBlue='\e[0;104m'    # Blue
On_IPurple='\e[0;105m'  # Purple
On_ICyan='\e[0;106m'    # Cyan
On_IWhite='\e[0;107m'   # White
