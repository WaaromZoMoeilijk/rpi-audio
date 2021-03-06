#!/bin/bash 
# shellcheck disable=SC2034,SC1090,SC1091,SC2010,SC2002,SC2015,SC2181,SC2129,SC2012
# Index
# Section A: Variables
# 	  B: Install.sh
#	  C: Audio.sh 
#	  D: Hardening
#	  E: Overclock
#	  F: Auto-start program
#	  G: Usb-unloader
#	  H: Bash colors
###################################################################### Section A: Variables
################################### Changeable by end user:
# Folders
LOG_DIR="/var/log"
GITDIR="/opt/rpi-audio"
MOUNT_DIR=/mnt # Mount folder (sda1 will be added underneath this)
USER="dietpi" # Pam user
USERNAME="$USER" # Will be removed
TITLE=$(/usr/bin/cat /etc/hostname) # Opusenc
ARTIST="RaspberryPI" # Opusenc
ALBUM="N/a" # Opusenc
GENRE="Recording" # Opusenc
GPG_RECIPIENT="recorder@waaromzomoeilijk.nl"
MINMB='2000' # Minimum storage capacity of / or USB storage in order to proceed
MAXPCT='95' # Max used % of / or USB storage used in order to proceed
DECRYPT_WAV_IN_DEST_FOLDER_FOR_DEBUG="1" # 1 = On / 0 = off - Also perform the reverse recording flow to test the audio and decrypting proc.
SSHDEV="1" # 1 = on / 0 = off - Add below pub key to the build for dev access, do not use in production.
SSHDEVKEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1ME48x4opi86nCvc6uT7Xz4rfhzR5/EGp24Bi/C21UOyyeQ3QBIzHSSBAVZav7I8hCtgaGaNcIGydTADqOQ8lalfYL6rpIOE3J4XyReqykLJebIjw9xXbD4uBx/2KFAZFuNybCgSXJc1XKWCIZ27jNpQUapyjsxRzQD/vC4vKtZI+XzosqNjUrZDwtAqP74Q8HMsZsF7UkQ3GxtvHgql0mlO1C/UO6vcdG+Ikx/x5Teh4QBzaf6rBzHQp5TPLWXV+dIt0/G+14EQo6IR88NuAO3gCMn6n7EnPGQsUpAd4OMwwEfO+cDI+ToYRO7vD9yvJhXgSY4N++y7FZIym+ZGz"
###################################################################### Please don't change anything below unless you know what you are doing.
################################### Folders
CONFIG="/boot/config.txt"
LOCALSTORAGE="/Recordings"
SCRIPT_DIR="$GITDIR/scripts"
LOG_FILE="$LOG_DIR/audio-usb-automount.log"
LOG_FILE_AUDIO="$LOG_DIR/audio-recording.log"
LOG_FILE_INSTALL="$LOG_DIR/audio-install.log"
LOG_FILE_AUTOSTART="$LOG_DIR/usb-autostart.log"
LOG_FILE_AUTOMOUNT="$LOG_DIR/usb-automount.log"
LOG_FILE_INITLOADER="$LOG_DIR/usb-initloader.log"
LOG_FILE_UNLOADER="$LOG_DIR/usb-unloader.log"
################################### USB automount/unmount vars
DEVICE="$3"  # USB device name (from kernel parameter passed from rule)
FILESYSTEM="$4"
AUTO_START="$5" 
AUTO_END="$4"
################################### System
#PASSWORD=$(whiptail --passwordbox "Please enter the password for the new user $USERNAME" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
#ROOTDRIVE=$(ls -la /dev/disk/by-partuuid/ | /usr/bin/grep "$(/usr/bin/cat /etc/fstab | /usr/bin/grep ' / ' | /usr/bin/awk '{print $1}' | /usr/bin/sed 's|PARTUUID=||g')" | /usr/bin/awk '{print $11}' | /usr/bin/sed "s|../../||g" | /usr/bin/sed 's/[0-9]*//g')
#DEV=$(/usr/bin/lshw -short -c disk | /usr/bin/grep -v "$ROOTDRIVE" | /usr/bin/awk '{print $2}' | /usr/bin/sed 's|path||g' | /usr/bin/sed -e '/^$/d')
DEV=$(/usr/bin/lshw -short -c disk | /usr/bin/awk '{print $2}' | /usr/bin/sed 's|path||g' | /usr/bin/sed -e '/^$/d')
#CHECKDRIVESIZE=$(/usr/bin/lshw -short -c disk | /usr/bin/grep -v "$ROOTDRIVE" | tail -n+3 | /usr/bin/awk '{print $2,$4}')
CHECKDRIVESIZE=$(/usr/bin/lshw -short -c disk | tail -n+3 | /usr/bin/awk '{print $2,$4}')
DEVID=$(ls -la /dev/disk/by-id/ | /usr/bin/grep "$DEV" | /usr/bin/grep -v 'part' | /usr/bin/awk '{print $9}' | /usr/bin/sed 's|:0||g')
BLOCKSIZE=$(blockdev --getbsz "$DEV")
USEP=$(df -h | /usr/bin/grep "$DEV" | /usr/bin/awk '{ print $5 }' | /usr/bin/cut -d'%' -f1)
USEM=$(df -h | /usr/bin/grep "$DEV" | /usr/bin/awk '{ print $3 }' | /usr/bin/cut -d'%' -f1)
LOCALSTORAGEUSED=$(df -Ph -BM "$LOCALSTORAGE" | tail -1 | /usr/bin/awk '{print $4}' | /usr/bin/sed 's|M||g')
################################### Network
WANIP4=$(/usr/bin/curl -s -k -m 5 https://ipv4bot.whatismyipaddress.com)
GATEWAY=$(ip route | /usr/bin/grep default | /usr/bin/awk '{print $3}')
IFACE=$(ip r | /usr/bin/grep "default via" | /usr/bin/awk '{print $5}')
ADDRESS=$(hostname -I | /usr/bin/cut -d ' ' -f 1)
################################### Links
ISSUES="https://github.com/WaaromZoMoeilijk/rpi-audio/issues"
REPO="https://github.com/WaaromZoMoeilijk/rpi-audio" 
################################### Misc
DATE=$(/usr/bin/date '+%Y-%m-%d - %H:%M:%S')
FOLDERDATE=$(/usr/bin/date '+%Y-%m-%d_%H%M')
FILEDATE=$(/usr/bin/date '+%Y-%m-%d_%H%M%S')
UFWSTATUS=$(/usr/sbin/ufw status)
################################### Storage
mic_count=$(/usr/bin/arecord --list-devices | /usr/bin/grep 'USB Microphone\|USB\|usb\|Usb\|Microphone\|MICROPHONE\|microphone\|mic\|Mic\|MIC' | /usr/bin/grep -c '^')
usb_count=$(find /mnt -iname '.active' | /usr/bin/sed 's|/.active||g' | /usr/bin/grep -c '^')
AUTO_START_FINISH=1 # Set to 0 if false; 1 if true
################################### Audio
CARD=$(/usr/bin/arecord -l | /usr/bin/grep -m 1 'USB Microphone\|USB\|usb\|Usb\|Microphone\|MICROPHONE\|microphone\|mic\|Mic\|MIC' | /usr/bin/awk '{print $2}' | /usr/bin/sed 's|:||g')
################################### Functions
is_root() {
	if [[ "$EUID" -ne 0 ]];	then
		return 1
	else
		return 0
	fi
}
###################################
root_check() {
	if ! is_root; then
		fatal "Failed, script needs sudo permissions for now"
	fi
}
###################################
debug_mode() {
	if [ "$DEBUG" -eq 1 ]; then
		set -ex
	fi
}
###################################
touch_log() {
	/usr/bin/mkdir -p "$LOG_DIR"
	touch "$LOG_FILE"
	touch "$LOG_FILE_INSTALL"
	touch "$LOG_FILE_AUTOSTART"
	touch "$LOG_FILE_AUTOMOUNT"
	touch "$LOG_FILE_INITLOADER"
	touch "$LOG_FILE_UNLOADER"
}
################################### easy colored output
success() {
	/usr/bin/echo -e "${IGreen} $* ${Color_Off}" >&2
}
warning() {
	/usr/bin/echo -e "${IYellow} $* ${Color_Off}" >&2
}
error() {
	/usr/bin/echo -e "${IRed} $* ${Color_Off}" >&2
}
header() {
	/usr/bin/echo -e "${IBlue} $* ${Color_Off}" >&2
}
fatal() {
	/usr/bin/echo -e "${IRed} $* ${Color_Off}" >&2
	exit 1
}
################################### Spinner during long commands
spinner() {
	#/usr/bin/printf '['
	while ps "$!" > /dev/null; do
	/usr/bin/echo -n '?????????'
	/usr/bin/sleep '.7'
	done
	#/usr/bin/echo ']'
}
###################################################################### Section B: install.sh
is_mounted() {
	/usr/bin/grep "$1" /etc/mtab
}
###################################
apt_install() {
	/usr/bin/apt-get install -y -qq -o=Dpkg::Use-Pty=0 && /usr/bin/echo -e "|" "${IGreen}Packages install done${Color_Off} |" >&2 || /usr/bin/echo -e "|" "${IRed}Packages install - Failed${Color_Off} |" >&2
}
apt_update() {
	/usr/bin/apt-get update -qq -o=Dpkg::Use-Pty=0 && /usr/bin/echo "Packages update done" || /usr/bin/echo "Packages update - Failed"
}
apt_upgrade() {
	sudo -E /usr/bin/apt-get -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" full-upgrade -y -qq && /usr/bin/echo "Packages upgrade done" || /usr/bin/echo "Packages upgrade - Failed"
}
apt_autoremove() {
	/usr/bin/apt-get autopurge -y -qq && /usr/bin/echo "Packages autopurge done" || /usr/bin/echo "Packages autopurge - Failed"
}
apt_autoclean() {
	/usr/bin/apt-get -y autoclean -qq && /usr/bin/echo "Packages clean done" || /usr/bin/echo "Packages clean - Failed"
}
###################################
install_if_not() {
	if ! dpkg-query -W -f='${Status}' "${1}" | /usr/bin/grep -q "ok installed"; then
	    /usr/bin/apt update -q4 & spinner_loading && RUNLEVEL=1 /usr/bin/apt install "${1}" -y
	fi
}
###################################
is_installed() {
	if ! dpkg-query -W -f='${Status}' "${1}" | /usr/bin/grep -q "ok installed"; then
		warning "${1} is not installed"
	else
		success "${1} is installed"
	fi
}
################################### Prefer IPv4 for apt
ipv4_apt() {
	header "[ ==  IPv4 APT Preference - $DATE == ]"
	if [ -f /etc/apt/apt.conf.d/99force-ipv4 ]; then
		warning "IPv4 Preference already set"
	else
		/usr/bin/echo 'Acquire::ForceIPv4 "true";' >> /etc/apt/apt.conf.d/99force-ipv4 && success "Set IPv4 Preference done" || error "Set IPv4 Preference failed"
	fi
}
################################### Upstart
rc_local() {
	header "[ ==  Setting up rc.local == ]"
	#if [ -f /etc/rc.local ]; then
	#	mv /etc/rc.local /etc/rc.local.backup."$DATE"
	#fi

	/usr/bin/systemctl disable rc-local.service || true
	/usr/bin/rm /etc/systemd/system/rc-local.service || true
	/usr/bin/systemctl daemon-reload || true

/usr/bin/cat > /etc/systemd/system/rc-local.service <<EOF
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local
[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99
[Install]
WantedBy=multi-user.target
EOF

# Add rc.local file
/usr/bin/cat > /etc/rc.local <<EOF
#!/bin/sh -e
/bin/bash $GITDIR/install.sh >> $LOG_FILE_INSTALL 2>&1&
exit 0
EOF

	/usr/bin/chmod +x /etc/rc.local
	/usr/bin/systemctl daemon-reload
	/usr/bin/systemctl enable rc-local.service
	/usr/bin/systemctl start rc-local.service
	if [ -f /etc/rc.local ]; then
		# Check if the above is succesfull
		if /usr/bin/cat /etc/rc.local | /usr/bin/grep -q "$GITDIR/install.sh"; then
			success "Setting up rc.local - Created"
		else
			error "Setting up rc.local failed, file exists but not the proper content"
		fi
	else
		error "Setting up rc.local failed"
	fi
} 
################################### Set timezone based upon WAN ip
tz_wan_ip() {
	header "[ ==  Set timezone based on WAN IP == ]"
	/usr/bin/timedatectl set-timezone Europe/Amsterdam &> /tmp/.tz || true
	if /usr/bin/cat /tmp/.tz | /usr/bin/grep -q "Failed to connect to bus: No such file or directory"; then
		warning "Timezone set failed (first install fails because of dbus dependency. Next run will set the timezone automatically)"
	else
		/usr/bin/curl -s --location --request GET 'https://api.ipgeolocation.io/timezone?apiKey=bbebedbbace2445386c258c0a472df1c' | jq '.timezone' | xargs /usr/bin/timedatectl set-timezone && success "Timezone set" || error "Timezone set failed"
	fi
}
#################################### Update
update_os() {
	header "[ ==  Update OS == ]"
	export "DEBIAN_FRONTEND=noninteractive"
	export "DEBIAN_PRIORITY=critical"
	header "[ ==  Auto clean == ]"
	#apt_autoclean & spinner
	header "[ ==  Auto purge == ]"
	#apt_autoremove & spinner
	header "[ ==  Update == ]"
	#apt_update & spinner
	header "[ ==  Upgrade == ]"
	#apt_upgrade & spinner
}
################################### Dependencies
dependencies_install() {
	header "[ ==  Dependencies == ]"
	/usr/bin/apt-get install -y -qq \
		git \
		jq \
		nano \
		curl \
		unattended-upgrades \
		net-tools \
		alsa-utils \
		opus-tools \
		ufw \
		rsyslog \
		fail2ban \
		dbus \
		lshw \
		ufw \
		rsync \
		par2 \
		gnupg1 && success "Packages install done" || error "Packages install failed"
}
################################### VDMFEC
vdmfec_install() {
	header "[ ==  VMDFEC == ]"
	if ! dpkg-query -W -f='${Status}' vdmfec | /usr/bin/grep -q "ok installed"; then
		warning "Vdmfec is not installed"

		# 64Bit, change for other arm distros
		/usr/bin/wget 'http://ftp.de.debian.org/debian/pool/main/v/vdmfec/vdmfec_1.0-2+b2_arm64.deb' && dpkg -i 'vdmfec_1.0-2+b2_arm64.deb' && /usr/bin/rm 'vdmfec_1.0-2+b2_arm64.deb'
		if ! dpkg-query -W -f='${Status}' vdmfec | /usr/bin/grep -q "ok installed"; then
			fatal "vdmfec install failed"
		else
			success "vdmfec installed"
		fi

	else
		success "vdmfec is already installed"
	fi
}
#####
################################### Allow access, temp during dev
dev_access() {
	if [ "$SSHDEV" == "1" ]; then
		header "[ ==  Dev access == ]"
		if [ -d "/root/.ssh" ]; then
			warning "Folder .ssh exists"
		else
			/usr/bin/mkdir -p /root/.ssh
			success "Folder /root/.ssh created"
		fi

		if /usr/bin/cat /root/.ssh/authorized_keys | /usr/bin/grep -q "$SSHDEVKEY"; then
			warning "Public key exists already"
		else
			/usr/bin/echo "$SSHDEVKEY" > /root/.ssh/authorized_keys && success "Pubkey added" || error "Pubkey appending failed"
		fi
	fi
}
################################### Create user
create_user() {
	header "[ ==  Creating user == ]"
	if /usr/bin/cat /etc/passwd | /usr/bin/grep -q "$USERNAME"; then
		warning "User exists"
	else
		/usr/bin/sudo useradd -m -p "$(openssl passwd -crypt "$PASSWORD")" "$USERNAME" && success "User added" || error "User add failed"
	fi
}
################################### Clone git repo
git_clone_pull() {
	header "[ ==  Clone/pull git repo == ]"
	if [ -d "$GITDIR" ]; then
		#/usr/bin/rm -r "$GITDIR"
		cd "$GITDIR" && success "Change dir to Git dir"  || error "Changing to Git dir failed"
		/usr/bin/git config pull.rebase false
		/usr/bin/git pull && success "Git repository updated"  || error "Git repository update failed"
	else
		/usr/bin/git clone "$REPO" "$GITDIR" && success "Git repository cloned" || error "Git repository failed to clone"
		/usr/bin/chmod +x "$GITDIR"/scripts/*.sh && success "Set permission on git repository" || error "Failed to set permission on git repository"
	fi
	
	/usr/bin/sed -i "s|source.*|source $GITDIR/lib.sh|g" "$GITDIR"/scripts/*.sh # Fix source in other scripts and speed up by not using WAN source files.
	/usr/bin/mkdir -p "$LOCALSTORAGE"
}
################################### Hardening
harden_system() {
	header "[ ==  Hardening == ]"
	bash "$GITDIR"/scripts/hardening.sh && success "Hardening executed" || error "Hardening failed"
}
################################### Dynamic overclock
overclock_pi() {
	# Please at minimum add some heat sinks to the RPI. Better to also add a FAN. thermal throtteling is in place at 75 celcius 
	# Overclocking dynamically will only affect the temp on high load for longer periods. You can mitigate that with above.
	header "[ ==  Overclock == ]"
	if /usr/bin/cat /proc/cpuinfo | /usr/bin/grep -q "Raspberry Pi 4"; then
		/bin/bash "$GITDIR"/scripts/overclock.sh && success "Overclock set, active on next reboot. Press shift during boot to disable" || error "Overclock set failed"
	fi
}
################################### GPG
gpg_keys() {
	header "[ ==  GPG keys == ]"
	if /usr/bin/gpg1 --homedir /root/.gnupg --list-key | /usr/bin/grep -q "${GPG_RECIPIENT}"; then
		warning "GPG key exist"
	else
		/usr/bin/echo -e "|" "${IBlue}GPG key creation" 
		#GPG_RECIPIENT="recorder@waaromzomoeilijk.nl"
		/usr/bin/gpg1 --homedir /root/.gnupg --list-keys

/usr/bin/cat >keydetails <<EOF
%/usr/bin/echo Generating a basic OpenPGP key
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Recorder
Name-Comment: Recorder
Name-Email: "${GPG_RECIPIENT}"
Expire-Date: 0
%no-ask-passphrase
%no-protection
#%pubring pubring.kbx
#%secring trustdb.gpg
%commit
%/usr/bin/echo done
EOF

		/usr/bin/gpg1 --verbose --homedir /root/.gnupg --batch --gen-key keydetails

		# Set trust to 5 for the key so we can encrypt without prompt.
		/usr/bin/echo -e "5\ny\n" |  /usr/bin/gpg1 --homedir /root/.gnupg --verbose --command-fd 0 --expert --edit-key "${GPG_RECIPIENT}" trust;

		# Test that the key was created and the permission the trust was set.
		/usr/bin/gpg1 --homedir /root/.gnupg --list-keys

		# Test the key can encrypt and decrypt.
		/usr/bin/gpg1 --homedir /root/.gnupg -e -a -r "${GPG_RECIPIENT}" keydetails

		# Delete the options and decrypt the original to stdout.
		/usr/bin/rm keydetails
		/usr/bin/gpg1 --homedir /root/.gnupg -d keydetails.asc
		/usr/bin/rm keydetails.asc

		if /usr/bin/gpg1 --homedir /root/.gnupg --list-key | /usr/bin/grep -q "${GPG_RECIPIENT}"; then
			warning "GPG key created"
		else
			error "GPG key creation failed" 
		fi	
	fi
}
################################### Storage, add auto mount & checks for usb drives
setup_usb() {
	header "[ ==  Storage == ]"
	if [ -f "/etc/udev/rules.d/85-usb-loader.rules" ]; then
		warning "/etc/udev/rules.d/85-usb-loader.rules exists"
	fi
	
	/usr/bin/rm -r /etc/udev/rules.d/85-usb-loader.rules
/usr/bin/cat >> /etc/udev/rules.d/85-usb-loader.rules <<EOF
ACTION=="add", KERNEL=="sd*[0-9]", SUBSYSTEMS=="usb", RUN+="$GITDIR/scripts/usb-initloader.sh ADD %k \$env{ID_FS_TYPE}"
ACTION=="remove", KERNEL=="sd*[0-9]", SUBSYSTEMS=="usb", RUN+="$GITDIR/scripts/usb-initloader.sh %k"
EOF
	udevadm control --reload-rules && success "Storage automation has been setup" || warning "Storage automation setup has failed"
}
################################### UPS
ups_setup() {
	header "[ ==  UPS == ]"
	#/bin/bash "$GITDIR"/scripts/ups.sh && success "UPS scripts executed" || error "UPS scripts failed"
}
################################### ZeroTier
zerotier_setup() {
	header "[ ==  Zerotier/networking == ]"
	#/bin/bash "$GITDIR"/scripts/zerotier.sh && success "Zerotier setup executed" || error "Zerotier setup failed"
}
################################### LED / Buttons
button_setup() {
	header "[ ==  LED/buttons == ]"
	#/bin/bash "$GITDIR"/scripts/ph.sh && success "LED / button script executed" || error "LED / button script execution failed"
}
################################### Finished installation flag
finished_installation_flag() {
	if [ -f "$GITDIR"/.rpi-audio-install.sh-finished ]; then
		/usr/bin/echo "Install script finished on $(date)" >> "$GITDIR"/.rpi-audio-install.sh-finished
	else
		/usr/bin/echo "Install script finished on $(date)" >> "$GITDIR"/.rpi-audio-install.sh-finished
		/usr/sbin/reboot 
	fi
}
################################### Audio start recording
start_recording() {
	header "[ ==  Start recording == ]"
	/usr/bin/echo "" >> "$LOG_FILE_AUDIO" ; /usr/bin/date >> "$LOG_FILE_AUDIO"
	/usr/bin/chmod +x "$GITDIR"/scripts/*.sh && success "Set permission on git repository" || error "Failed to set permission on git repository"
	/bin/bash "$GITDIR"/scripts/audio.sh >> "$LOG_FILE_AUDIO" 2>&1
}
###################################################################### Section B: install.sh

###################################################################### Section C: audio.sh
##################################### Stop all recordings just to be sure
stop_all_recordings() {
	if /usr/bin/pgrep 'arecord'; then
		/usr/bin/pkill -2 'arecord' && success "SIGINT send for arecord" || fatal "Failed to SIGINT arecord" 
		#LED/beep that mic is not detected ; /usr/bin/sleep 10 && /usr/sbin/reboot 
		/usr/bin/sleep 2
	fi

	if [ -f /tmp/.recording.lock ]; then
		/usr/bin/rm /tmp/.recording.lock
	fi
}
##################################### In progress flag
/usr/bin/echo "Start recording $DATE" > /tmp/.recording.lock
mountvar() {
	header "[ ==  Checking for USB drives. == ]"
	if [[ $(find /mnt -iname '.active' | /usr/bin/sed 's|/.active||g') ]]; then
		MNTPT=$(find /mnt -iname '.active' | /usr/bin/sed 's|/.active||g')
		success "Active drive has been found, proceeding"
	else
		warning "No active drive has been found, setting one up."
	fi
}

check_usb_drives() {
	# check for double drives.
	# checks lines count and invokes needed script or exit.
	# if 0 lines - exit
	# if 1 lines - continue
	# if any other number of lines - exit
	case $usb_count in
	    0) fatal "No active USB storage device has been found, please reinsert and run again" #LED/beep that mic is not detected && /usr/bin/sleep 10 && /usr/sbin/reboot 
	    ;;
	    1) mountvar
	    ;;
	    *) fatal "More then 1 USB storage device found, this is not supported yet"
	    ;;
	esac
}
##################################### Check if storage is writable
storage_writable_check() {
	header "[ ==  Checking if the storage is writable. == ]"
	touch "$MNTPT"/.test
	if [ -f "$MNTPT/.test" ]; then
		success "Storage is writable"
		/usr/bin/rm "$MNTPT"/.test
	else
		error "Storage is not writable, exiting."
		#LED/beep that mic is not detected
		# /usr/bin/sleep 10 && /usr/sbin/reboot 
		exit 1
	fi
}
##################################### Check free space
check_freespace_prior() {
	header "[ ==  Checking free space available on root. == ]"
	if [ "$LOCALSTORAGEUSED" -le "$MINMB" ]; then
		error "Less then $MINMB MB available on the local storage directory $LOCALSTORAGEUSED MB (Not USB)"
		#LED/beep that mic is not detected
		# /usr/bin/sleep 10 && /usr/sbin/reboot 		
	else
		success "More then $MINMB MB available on the local storage directory $LOCALSTORAGEUSED MB (Not USB)"
	fi      

	header "[ ==  Checking free space available on storage. == ]"
	if [ "$USEP" -ge "$MAXPCT" ]; then
		error "Drive has less then 10% storage capacity available, please free up space."
		#LED/beep that mic is not detected
		# /usr/bin/sleep 10 && /usr/sbin/reboot 
	else
		success "Drive has more then 10% capacity available, proceeding"
	fi

	if [ "$(df -Ph -BM "$MNTPT" | tail -1 | /usr/bin/awk '{print $4}' | /usr/bin/sed 's|M||g')" -le "$MINMB" ]; then
		fatal "Less then $MINMB MB available on usb storage directory: used: $USEM (USB)"
		#LED/beep that mic is not detected
		# /usr/bin/sleep 10 && /usr/sbin/reboot 
	else
		success "More then $MINMB MB available on usb storage directory, used: $USEM (USB)"
	fi
}
##################################### Check for USB Mic
check_usb_mic() {
	header "[ ==  Checking for USB Mics. Please have only 1 USB Mic/soundcard connected for now == ]"
	# check for number of MICs
	# checks lines count and invokes needed script or exit.
	# if 0 lines - exit
	# if 1 lines - continue
	# if any other number of lines - exit
	case $mic_count in  
	    0) fatal "No USB Microphone detected! Please plug one in now, and restart or replug USB" #LED/beep that mic is not detected ; /usr/bin/sleep 10 && /usr/sbin/reboot 
	    ;;  
	    1) success "USB Microphone detected!"
	    ;;  
	    *) fatal "More then 1 USB Mic found this is not yet supported" #LED/beep that mic is not detected ; /usr/bin/sleep 10 && /usr/sbin/reboot 
	    ;;  
	esac
}
##################################### Set volume and unmute
set_vol() {
	header "[ ==  Set volume and unmute == ]"
	/usr/bin/amixer -q -c "$CARD" set Mic 80% unmute && success "Mic input volume set to 80% and is unmuted" || fatal "Failed to set input volume" # ; LED/beep that mic is not detected
}
##################################### Test recording
test_rec() {
	header "[ ==  Test recording == ]"
	/usr/bin/arecord -q -f S16_LE -d 3 -r 48000 --device="hw:$CARD,0" /tmp/test-mic.wav && success "Test recording is done" || fatal "Test recording failed" # ; LED/beep that mic is not detected		
}
##################################### Check recording file size
check_rec_filesize() {
	header "[ ==  Check if recording file size is not 0 == ]"
	if [ -s /tmp/test-mic.wav ]; then
		success "File contains data"
	else
		error "File is empty! Unable to record."
		#LED/beep that mic is not detected
		# /usr/bin/sleep 10 && /usr/sbin/reboot 		
	fi
}
##################################### Test playback
test_playback() {
	header "[ ==  Testing playback of the recording == ]"
	/usr/bin/aplay  /tmp/test-mic.wav
	if [ $? -eq 0 ]; then
		success "Playback is ok"
		/usr/bin/rm -r /tmp/test-mic.wav
	else
		error "Playback failed"
		/usr/bin/rm -r /tmp/test-mic.wav\
		#LED/beep that mic is not detected
		# /usr/bin/sleep 10 && /usr/sbin/reboot 		
	fi
}
##################################### Check for double channel
check_double_channel() {
	header "[ ==  Double channel check == ]"
	# channel=$()
	# if channel = 2 then
	#else
	#fi
}
##################################### Recording flow: audio-out | /usr/bin/opusenc | /usr/bin/gpg1 | vdmfec | split/tee
record_audio() {
	/usr/bin/mkdir "$MNTPT/$FOLDERDATE" && success "Created $MNTPT/$FOLDERDATE" || error "Failed to create $MNTPT/$FOLDERDATE"
	/usr/bin/arecord -f S16_LE -d 0 -r 48000 --device="hw:$CARD,0" | \
	/usr/bin/opusenc --vbr --bitrate 128 --comp 10 --expect-loss 8 --framesize 60 --title "$TITLE" --artist "$ARTIST" --date "$(/usr/bin/date +%Y-%M-%d)" --album "$ALBUM" --genre "$GENRE" - - | \
	/usr/bin/gpg1 --homedir /root/.gnupg --encrypt --recipient "${GPG_RECIPIENT}" --sign --verbose --armour --force-mdc --compress-level 0 --compress-algo none \
	     --no-emit-version --no-random-seed-file --no-secmem-warning --personal-cipher-preferences AES256 --personal-digest-preferences SHA512 \
		 --personal-compress-preferences none --cipher-algo AES256 --digest-algo SHA512 | \
	vdmfec -v -b "$BLOCKSIZE" -n 32 -k 24 | \
	tee "$MNTPT/$FOLDERDATE/$FILEDATE.wav.gpg" 
	clear
	/usr/bin/sleep 3

	if [ -f "$MNTPT/$FOLDERDATE/$FILEDATE.wav.gpg" ]; then
		success "Recording is done"
	else
		error "Something went wrong during the recording flow"
	fi

	if [ "$DECRYPT_WAV_IN_DEST_FOLDER_FOR_DEBUG" == "1" ]; then
		# Reverse Pipe
		vdmfec -v -d -b "$BLOCKSIZE" -n 32 -k 24 "$MNTPT/$FOLDERDATE/$FILEDATE.wav.gpg" | /usr/bin/gpg1 --homedir /root/.gnupg --decrypt > "$MNTPT/$FOLDERDATE/$FILEDATE.decrypted.wav"
	fi

	# SIGINT arecord - control + c equivilant. Used to end the arecord cmd and continue the pipe. Triggered when UPS mains is unplugged.
	#/usr/bin/pkill -2 'arecord'

	# Error finding card
	# ALSA lib pcm_hw.c:1829:(_snd_pcm_hw_open) Invalid value for card

	# GPG additions
	#--passphrase-file file reads the passphrase from a file
	#--passphrase string uses string as the passphrase
	# For production we also want to add --batch, which prevents gpg from using interactive commands, and --no-tty, which makes sure that the terminal isn't used for any output.
}
###################################### Create par2 files
create_par2() {
	# Implement a last modified file check for the latest recording only
	par2 create "$MNTPT/$FOLDERDATE/$FILEDATE.wav.gpg.par2" "$MNTPT/$FOLDERDATE/$FILEDATE.wav.gpg" && success "Par2 file created" || error "Failed to create Par2 file"
}
###################################### Verify par2 files
verify_par2() {
	if par2 verify "$MNTPT/$FOLDERDATE/$FILEDATE.wav.gpg.par2" | /usr/bin/grep "All files are correct, repair is not required"; then
		success "Par2 verified"
	else
		error "Par2 verification failed"
	fi
}
##################################### Check free space after recording
check_freespace_post() {
	header "[ ==  Checking free space available on storage after recording. == ]"
	if [ "$USEP" -ge "$MAXPCT" ]; then
		error "Drive has less then 10% storage capacity available, please free up space."
	else
		success "Drive has more then 10% capacity available, proceeding"
	fi

	if [ "$(df -Ph -BM "$MNTPT" | tail -1 | /usr/bin/awk '{print $4}' | /usr/bin/sed 's|M||g')" -le "$MINMB" ]; then
		error "Less then $MINMB MB available on usb storage directory $USEM (USB)"
	else
		success "More then then $MINMB MB available on usb storage directory $USEM (USB)"
	fi
}
##################################### Backup recordings ///// make this split
backup_recordings() {
	if [ -d "$LOCALSTORAGE" ]; then
		/usr/bin/chown -R "$USER":"$USER" "$LOCALSTORAGE"
	else
		/usr/bin/mkdir -p "$LOCALSTORAGE"
		/usr/bin/chown -R "$USER":"$USER" "$LOCALSTORAGE"
	fi

	if [ "$LOCALSTORAGEUSED" -le "$MINMB" ]; then
		error "Less then $MINMB MB available on the local storage directory $LOCALSTORAGEUSED MB (Not USB)"
	else
		success "More then $MINMB MB available on the local storage directory $LOCALSTORAGEUSED MB (Not USB)"
		/usr/bin/rsync -aAXHv "$MNTPT/" "$LOCALSTORAGE/"
	fi      
}
##################################### Sync logs to USB
sync_to_usb() {
	/usr/bin/mkdir -p "$MNTPT/Logs/OS"	
	/usr/bin/mkdir -p "$MNTPT/Logs/$FOLDERDATE"
	/usr/bin/chown -R "$USER":"$USER" "$MNTPT"
	/usr/bin/rsync -rltDvz --exclude='dietpi-ramlog_store' /var/tmp/dietpi/logs/ "$MNTPT/Logs/OS/" && success "OS Log files synced to USB device" || warning "OS Log file syncing failed or had some errors - USB"
	/usr/bin/rsync -rltDvz /var/log/{usb*,audio*} "$MNTPT/Logs/$FOLDERDATE/" && success "APP Log files synced to USB device" || warning "APP Log file syncing failed or had some errors - USB"
	# Ext4 linux partition for use on other linux systems, fix
	/usr/bin/chmod -R 777 "$MNTPT"
	/usr/bin/chown -R "$USER":"$USER" "$MNTPT"
}
##################################### Unmount device
unmount_device() {
	MNTPTR=$(find /mnt -iname '.active' | /usr/bin/sed 's|/Recordings/.active||g')
	if [ -d "$MNTPTR" ]; then
		sync		
		/usr/bin/systemd-umount "$MNTPTR" && success "Systemd-unmounted succeeded" || warning "Systemd-unmounted failed, probably did not exist"
		/usr/bin/systemctl disable "mnt-$DEVICE.mount" && success "/usr/bin/systemctl disable mnt-$DEVICE.mount" || warning "/usr/bin/systemctl disable mnt-$DEVICE.mount failed, probably did not exist"
		/usr/bin/systemctl daemon-reload 
		/usr/bin/umount "$MNTPTR" && success "Unmount succeeded" || warning "Unmounting failed, probably did not exist"
		/usr/bin/umount -l "$MNTPTR" && success "Unmounted -l succeeded" || warning "Unmounting -l failed, probably did not exist"
		/usr/bin/rmdir "$MNTPTR" && success "Removed directory $MNTPTR" || error "Directory removal of $MNTPTR failed, probably did not exist"
		/usr/bin/rmdir "$MOUNT_DIR"/sd*
		if [ -d "$MNTPTR" ]; then
			fatal "something went wrong unmounting please check the logs"
		else
			success "Unmount succeeded"
		fi
	fi

	/usr/bin/systemd-umount "$MNTPTR"
	if [ $? -eq 0 ]; then
		success "Systemd-unmount done"
		# Remove folder after unmount
		/usr/bin/sleep 2
		/usr/bin/rmdir "$MNTPTR" && success "$MNTPTR folder removed" || error "$MNTPTR folder remove failed"
	else
		error "Systemd-umount failed"
		/usr/bin/umount -l "$MNTPTR" && success "umount -l done" || error "Umount -l - Not mounted double check, done"
		#/usr/bin/systemctl disable "$MOUNT_DIR-$DEVICE".mount && success "/usr/bin/systemctl disabled $MOUNT_DIR-$DEVICE.mount done" || error "/usr/bin/systemctl disabled $MOUNT_DIR-$DEVICE.mount failed"
		#/usr/bin/systemctl daemon-reload && success "/usr/bin/systemctl daemon-reload done" || error "/usr/bin/systemctl daemon-reload failed"
		#/usr/bin/systemctl reset-failed && success "/usr/bin/systemctl reset-failed done" || error "/usr/bin/systemctl reset-failed failed"
		# Remove folder after unmount
		/usr/bin/sleep 2
		/usr/bin/rmdir "$MNTPTR" && success "$MNTPTR folder removed" || error "$MNTPTR folder remove failed"
	fi	

	# test that this device has disappeared from mounted devices
	device_mounted=$(/usr/bin/grep -q "$DEV" /etc/mtab)
	if [ "$device_mounted" ]; then
		error "Failed to Un-Mount, forcing umount -l"
		/usr/bin/echo "temp disable of unmount for dev"
		/usr/bin/umount -l "/dev/$DEVICE" && success "umount -l done" || error "Umount -l - Not mounted double check, done"
	else
		success "Device not present in /etc/mtab"
	fi
}
###################################################################### Section C: audio.sh

###################################################################### Section D: hardening
hardening() {
	# fail2ban install
	FB=$(dpkg-query -W -f='${Status}' fail2ban)
	if [ "$FB" == "install ok installed" ]; then
		/usr/bin/echo -e "${IYellow}Fail2ban is already installed${Color_Off}" >&2
	else
		/usr/bin/apt install fail2ban -y -qq

		/usr/bin/wget -O /etc/fail2ban/jail.local https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/static/jail.local

		/usr/bin/systemctl restart fail2ban

		if [ "$FB" == "install ok installed" ]; then
			/usr/bin/echo -e "|" "${IGreen}Fail2ban install - Done${Color_Off} |" >&2
		else
			/usr/bin/echo -e "|" "${IRed}Fail2ban install - Failed${Color_Off} |" >&2
		fi
	fi

	if [ "$UFWSTATUS" == "ERROR: Couldn't determine iptables version" ]; then
		update-alternatives --set iptables /usr/sbin/iptables-legacy && success "Fixed iptables issue with UFW. Next reboot will set firewall rules" || error "Failed to fix iptables issue with UFW"
	#elif [ "$UFWSTATUS" == "ERROR: problem running iptables: iptables v1.8.7 (legacy): can't initialize iptables table `filter': Table does not exist (do you need to insmod?)
	#Perhaps iptables or your kernel needs to be upgraded." ]; then
	#        warning "We need a reboot in order to use UFW with iptables"
	else
	/usr/bin/echo "y" | ufw reset
	ufw default allow outgoing
	ufw default deny incoming
	ufw limit 22/tcp
	/usr/bin/echo "y" | ufw enable
	fi
}
###################################################################### Section D: hardening

###################################################################### Section E: Overclock
overclock_rpi() {
	# No core freq changes for RPI4 
	# https://www.raspberrypi.org/documentation/configuration/config-txt/overclocking.md
	# https://elinux.org/RPiconfig

	CONFIG="/boot/config.txt"

	/usr/bin/sed -i '/arm_freq=/d' "$CONFIG"
	/usr/bin/sed -i '/arm_freq_min=/d' "$CONFIG"
	/usr/bin/sed -i '/over_voltage=/d' "$CONFIG"
	/usr/bin/sed -i '/over_voltage_min=/d' "$CONFIG"
	/usr/bin/sed -i '/temp_limit=/d' "$CONFIG"
	/usr/bin/sed -i '/initial_turbo=/d' "$CONFIG"
	/usr/bin/sed -i '/core_freq/d' "$CONFIG"
	/usr/bin/sed -i '/sdram_freq/d' "$CONFIG"
	/usr/bin/sed -i '/-------Overclock-------/d' "$CONFIG"

# Dynamic overclock config
/usr/bin/cat >> "$CONFIG" <<EOF
#-------Overclock-------
arm_freq=2000
arm_freq_min=600
over_voltage=6
over_voltage_min=0
temp_limit=75
initial_turbo=60
EOF
}
###################################################################### Section E: Overclock

###################################################################### Section F: auto-start program
automount() {
    header "[ ==  USB Auto Mount $DATE == ]"

    # Allow time for device to be added
    /usr/bin/sleep 2
 
	# Fix, disable leftover systemd mounts
	if systemd-mount --list | grep -q "$DEVICE"; then
		/usr/bin/systemd-umount "$MOUNT_DIR/$DEVICE" && success "Systemd-unmounted succeeded" || warning "Systemd-unmounted failed, probably did not exist"
		/usr/bin/systemctl disable "mnt-$DEVICE.mount" && success "/usr/bin/systemctl disable mnt-$DEVICE.mount" || warning "/usr/bin/systemctl disable mnt-$DEVICE.mount failed, probably did not exist"
		/usr/bin/systemctl daemon-reload 
	fi

	/usr/bin/systemctl reset-failed && success "/usr/bin/systemctl reset-failed" || warning "/usr/bin/systemctl reset-failed"

	# Check old mountpoint
    is_mounted "$DEVICE" && fatal "seems /dev/$DEVICE is already mounted"

    # test mountpoint - it shouldn't exist
	if [ -d "$MOUNT_DIR/$DEVICE" ]; then
		/usr/bin/rmdir "$MOUNT_DIR/$DEVICE"  
	fi

    [ -e "$MOUNT_DIR/$DEVICE" ] && fatal "It seems mountpoint $MOUNT_DIR/$DEVICE already exists"

    # make the mountpoint
    /usr/bin/mkdir "$MOUNT_DIR/$DEVICE" && success "Mountpoint $MOUNT_DIR/$DEVICE created" || fatal "Mountpoint $MOUNT_DIR/$DEVICE creation failed"

    # make sure the user owns this folder
    /usr/bin/chown -R "$USER":"$USER" "$MOUNT_DIR/$DEVICE" && success "/usr/bin/chown $USER:$USER on $MOUNT_DIR/$DEVICE set" || fatal "/usr/bin/chown $USER:$USER on $MOUNT_DIR/$DEVICE failed"

    # mount the device base on USB file system
    case "$FILESYSTEM" in
        vfat) systemd-mount -t vfat -o utf8,uid="$USER",gid="$USER" "/dev/$DEVICE" "$MOUNT_DIR/$DEVICE" && success "Mounted VFAT partition" || fatal "Failed mounting VFAT parition"
              ;;
        ntfs) fatal "NTFS is currently not supported, please reformat to FAT after a backup" #systemd-mount -t auto -o uid="$USER",gid="$USER",errors=continue "/dev/$DEVICE" "$MOUNT_DIR/$DEVICE" || fatal "Failed mounting NTFS partition" 
              ;;
        ext*) systemd-mount -t auto -o sync,noatime "/dev/$DEVICE" "$MOUNT_DIR/$DEVICE" && success "Mounted EXT partition" || fatal "Failed mounting EXT partition"
              ;;	
     esac
} 
#################################### Auto Start Function
autostart() {
    header "[ ==  USB Auto Start Program == ]"
    DEV=$(/usr/bin/echo "$DEVICE" | /usr/bin/cut -c -3)
    # Check # of partitions
    if [[ $(/usr/bin/grep -c "$DEV"'[0-9]' /proc/partitions) -gt 1 ]]; then
        fatal "More then 1 parition detected, please format your drive and create a single FAT32/NTFS/EXT partition and try again"
    elif [[ $(/usr/bin/grep -c "$DEV"'[0-9]' /proc/partitions) -eq 0 ]]; then
        fatal "No parition detected, please format your drive and create a single FAT32/NTFS/EXT partition and try again"
    elif [[ $(/usr/bin/grep -c "$DEV"'[0-9]' /proc/partitions) -eq 1 ]]; then
        success "1 partition detected, checking if its been used before"
        # Check if drive is empty
        if [ -f "$(ls -I '.Trash*' -A "$MOUNT_DIR/$DEVICE")" ]; then
            # Empty
            warning "EMPTY"
            /usr/bin/mkdir "$MOUNT_DIR/$DEVICE/Recordings" && success "Created $MOUNT_DIR/$DEVICE/Recordings" || error "Failed to create $MOUNT_DIR/$DEVICE/Recordings"
            /usr/bin/echo "$MOUNT_DIR/$DEVICE $DEVID $DATE" >> "$MOUNT_DIR/$DEVICE/Recordings/.active" && success "Written device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active" || error "Failed to write device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active"
            /usr/bin/chown -R "$USER":"$USER" "$MOUNT_DIR/$DEVICE" && success "Set permissions on $MOUNT_DIR/$DEVICE" || error "Set permissions on $MOUNT_DIR/$DEVICE failed"
            # Temporary export GPG keys to storage device.
            /usr/bin/mkdir "$MOUNT_DIR/$DEVICE/DevGnupg" && success "Created temp dev gnupg folder" || error "Failed to create temp dev gnupg folder"
            /usr/bin/gpg1 --export-ownertrust > "$MOUNT_DIR/$DEVICE/DevGnupg/otrust.txt"
            /usr/bin/gpg1 -a --export-secret-keys > "$MOUNT_DIR/$DEVICE/DevGnupg/privatekey.asc"
            /usr/bin/gpg1 -a --export > "$MOUNT_DIR/$DEVICE/DevGnupg/publickey.asc"
        else
            # Not Empty
            # Check if .active resides in Recordings/
            if [ -f "$MOUNT_DIR/$DEVICE/Recordings/.active" ]; then
                # Yes
                warning "NOT EMPTY - Device has already been setup previously, importing" 
                /usr/bin/echo "$MOUNT_DIR/$DEVICE $DEVID $DATE" >> "$MOUNT_DIR/$DEVICE/Recordings/.active" && success "Written device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active" || error "Failed to write device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active"
                /usr/bin/chown -R "$USER":"$USER" "$MOUNT_DIR/$DEVICE" && success "Set permissions on $MOUNT_DIR/$DEVICE" || error "Set permissions on $MOUNT_DIR/$DEVICE failed"
                if [ -d "$MOUNT_DIR/$DEVICE"/DevGnupg ]; then
                    warning "Temporary Dev GPG key folder is populated already, skipping" 
                else
                    /usr/bin/echo "Temporary Dev GPG key folder is empty, copying"
                    # Temporary export GPG keys to storage device.
                    /usr/bin/mkdir "$MOUNT_DIR/$DEVICE/DevGnupg" && success "Created temp dev gnupg folder" || error "Failed to create temp dev gnupg folder, probably exists already."
                    /usr/bin/gpg1 --export-ownertrust > "$MOUNT_DIR/$DEVICE/DevGnupg/otrust.txt"
                    /usr/bin/gpg1 -a --export-secret-keys > "$MOUNT_DIR/$DEVICE/DevGnupg/privatekey.asc"
                    /usr/bin/gpg1 -a --export > "$MOUNT_DIR/$DEVICE/DevGnupg/publickey.asc"					
                fi
            else
                # No
                /usr/bin/echo
                /usr/bin/mkdir "$MOUNT_DIR/$DEVICE/Recordings" && success "Created $MOUNT_DIR/$DEVICE/Recordings" || error "Failed to create $MOUNT_DIR/$DEVICE/Recordings, probably exists already."
                /usr/bin/echo "$MOUNT_DIR/$DEVICE $DEVID $DATE" >> "$MOUNT_DIR/$DEVICE/Recordings/.active" && success "Written device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active" || error "Failed to write device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active"
                /usr/bin/chown -R "$USER":"$USER" "$MOUNT_DIR/$DEVICE" && success "Set permissions on $MOUNT_DIR/$DEVICE" || error "Set permissions on $MOUNT_DIR/$DEVICE failed"
                # Temporary export GPG keys to storage device.
                /usr/bin/mkdir "$MOUNT_DIR/$DEVICE/DevGnupg" && success "Created temp dev gnupg folder" || error "Failed to create temp dev gnupg folder, probably exists already."
                /usr/bin/gpg1 --export-ownertrust > "$MOUNT_DIR/$DEVICE/DevGnupg/otrust.txt"
                /usr/bin/gpg1 -a --export-secret-keys > "$MOUNT_DIR/$DEVICE/DevGnupg/privatekey.asc"
                /usr/bin/gpg1 -a --export > "$MOUNT_DIR/$DEVICE/DevGnupg/publickey.asc"
            fi
        fi
    fi
    # Start audio recording
    header "[ ==  Start recording == ]"
	/usr/bin/echo >> "$LOG_FILE_AUDIO"
    /usr/bin/date >> "$LOG_FILE_AUDIO"
    /bin/bash "$GITDIR"/scripts/audio.sh >> "$LOG_FILE_AUDIO" 2>&1
}
###################################################################### Section F: auto-start program

###################################################################### Section G: usb-unloader.sh
autounload() {
	header "[ ==  USB UnLoader == ]" 
	[ "$MOUNT_DIR" ] || fatal "Failed to supply Mount Dir parameter"
	[ "$DEVICE" ] || fatal "Failed to supply DEVICE parameter"

	if [ -d "$MOUNT_DIR/$DEVICE" ]; then

		/usr/bin/umount -q "$MOUNT_DIR/$DEVICE" && success "Unmount succeeded" || warning "Unmounting failed, probably did not exist"
		/usr/bin/umount -q -l "$MOUNT_DIR/$DEVICE" && success "Unmounted -l succeeded" || warning "Unmounting -l failed, probably did not exist"
		
		if systemd-mount --list | grep -q "$DEVICE"; then
			/usr/bin/systemd-umount "$MOUNT_DIR/$DEVICE" && success "Systemd-unmounted succeeded" || warning "Systemd-unmounted failed, probably did not exist"
			/usr/bin/systemctl disable "mnt-$DEVICE.mount" && success "/usr/bin/systemctl disable mnt-$DEVICE.mount" || warning "/usr/bin/systemctl disable mnt-$DEVICE.mount failed, probably did not exist"
			/usr/bin/systemctl daemon-reload 
		fi

		/usr/bin/rmdir "$MOUNT_DIR/$DEVICE" && success "Removed directory $MOUNT_DIR/$DEVICE" || error "Directory removal of $MOUNT_DIR/$DEVICE failed, probably did not exist"
		find "$MOUNT_DIR" -type d -iname "sd*" -exec rmdir {} \;

		if [ -d "$MOUNT_DIR/$DEVICE" ]; then
			fatal "something went wrong unmounting please check the logs"
		else
			success "Unmount succeeded"
		fi
	fi
}
###################################################################### Section G: usb-unloader.sh

###################################################################### Section H: Bash colors
print_text_in_color() {
/usr/bin/printf "%b%s%b\n" "$1" "$2" "$Color_Off"
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
###################################################################### Section H: Bash colors
