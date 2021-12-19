#!/bin/bash 
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
TITLE=$(cat /etc/hostname) # Opusenc
ARTIST="RaspberryPI" # Opusenc
ALBUM="N/a" # Opusenc
GENRE="Recording" # Opusenc
GPG_RECIPIENT="recorder@waaromzomoeilijk.nl"
MINMB='2000' # Minimum storage capacity of / or USB storage in order to proceed
MAXPCT='95' # Max used % of / or USB storage used in order to proceed
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
ROOTDRIVE=$(ls -la /dev/disk/by-partuuid/ | grep "$(cat /etc/fstab | grep ' / ' | awk '{print $1}' | sed 's|PARTUUID=||g')" | awk '{print $11}' | sed "s|../../||g" | sed 's/[0-9]*//g')
#ROOTDRIVE=$(df -k / | sed -n '2p' | awk {'print $1'})
DEV=$(lshw -short -c disk | grep -v "$ROOTDRIVE" | awk '{print $2}' | sed 's|path||g' | sed -e '/^$/d')
CHECKDRIVESIZE=$(lshw -short -c disk | grep -v "$ROOTDRIVE" | tail -n+3 | awk '{print $2,$4}')
DEVID=$(ls -la /dev/disk/by-id/ | grep "$DEV" | grep -v 'part' | awk '{print $9}' | sed 's|:0||g')
BLOCKSIZE=$(blockdev --getbsz "$DEV")
USEP=$(df -h | grep "$DEV" | awk '{ print $5 }' | cut -d'%' -f1)
LOCALSTORAGEUSED=$(df -Ph -BM "$LOCALSTORAGE" | tail -1 | awk '{print $4}' | sed 's|M||g')
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
mic_count=$(echo -n "$OUTPUTMIC" | grep -c '^')
usb_count=$(echo -n "$OUTPUTUSB" | grep -c '^')
OUTPUTMIC=$(arecord --list-devices | grep 'USB Microphone\|USB\|usb\|Usb\|Microphone\|MICROPHONE\|microphone\|mic\|Mic\|MIC') # $1 Process Id
OUTPUTUSB=$(find /mnt -iname '.active' | sed 's|/.active||g') # $1 Process Id
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
	if ! is_root; then
		fatal "Failed, script needs sudo permissions for now"
		exit 1
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
	mkdir -p "$LOG_DIR"
	touch "$LOG_FILE"
	touch "$LOG_FILE_INSTALL"
	touch "$LOG_FILE_AUTOSTART"
	touch "$LOG_FILE_AUTOMOUNT"
	touch "$LOG_FILE_INITLOADER"
	touch "$LOG_FILE_UNLOADER"
}
################################### easy colored output
success() {
	echo -e "${IGreen} $* ${Color_Off}" >&2
}
warning() {
	echo -e "${IYellow} $* ${Color_Off}" >&2
}
error() {
	echo -e "${IRed} $* ${Color_Off}" >&2
}
header() {
	echo -e "${IBlue} $* ${Color_Off}" >&2
}
fatal() {
	echo -e "${IRed} $* ${Color_Off}" >&2
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
###################################################################### Section B: install.sh
is_mounted() {
	grep "$1" /etc/mtab
}
###################################
apt_install() {
	apt-get install -y -qq -o=Dpkg::Use-Pty=0 && echo -e "|" "${IGreen}Packages install done${Color_Off} |" >&2 || echo -e "|" "${IRed}Packages install - Failed${Color_Off} |" >&2
}
apt_update() {
	apt-get update -qq -o=Dpkg::Use-Pty=0 && echo "Packages update done" || echo "Packages update - Failed"
}
apt_upgrade() {
	sudo -E apt-get -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" full-upgrade -y -qq && echo "Packages upgrade done" || echo "Packages upgrade - Failed"
}
apt_autoremove() {
	apt-get autopurge -y -qq && echo "Packages autopurge done" || echo "Packages autopurge - Failed"
}
apt_autoclean() {
	apt-get -y autoclean -qq && echo "Packages clean done" || echo "Packages clean - Failed"
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
################################### Prefer IPv4 for apt
ipv4_apt() {
	header "[ ==  IPv4 APT Preference - $DATE == ]"
	if [ -f /etc/apt/apt.conf.d/99force-ipv4 ]; then
		warning "IPv4 Preference already set"
	else
		echo 'Acquire::ForceIPv4 "true";' >> /etc/apt/apt.conf.d/99force-ipv4
		if [ $? -eq 0 ]; then
			success "Set IPv4 Preference done"
		else
			error "Set IPv4 Preference failed"
		fi
	fi
}
################################### Upstart
rc_local() {
	header "[ ==  Setting up rc.local == ]"
	if [ -f /etc/rc.local ]; then
		mv /etc/rc.local /etc/rc.local.backup."$DATE"
	fi

	systemctl disable rc-local.service || true
	rm /etc/systemd/system/rc-local.service || true
	systemctl daemon-reload || true

cat > /etc/systemd/system/rc-local.service <<EOF
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
cat > /etc/rc.local <<EOF
#!/bin/sh -e
/bin/bash $GITDIR/install.sh >> $LOG_FILE_INSTALL 2>&1&
exit 0
EOF

	chmod +x /etc/rc.local
	systemctl daemon-reload
	systemctl enable rc-local.service
	systemctl start rc-local.service
	if [ -f /etc/rc.local ]; then
		# Check if the above is succesfull
		if cat /etc/rc.local | grep -q "$GITDIR/install.sh"; then
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
	timedatectl set-timezone Europe/Amsterdam &> /tmp/.tz || true
	if echo $(cat /tmp/.tz) | grep -q "Failed to connect to bus: No such file or directory"; then
		warning "Timezone set failed (first install fails because of dbus dependency. Next run will set the timezone automatically)"
	else
		curl -s --location --request GET 'https://api.ipgeolocation.io/timezone?apiKey=bbebedbbace2445386c258c0a472df1c' | jq '.timezone' | xargs timedatectl set-timezone
		if [ $? -eq 0 ]; then
			success "Timezone set"
		else
			error "Timezone set failed"
		fi
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
	apt-get install -y -qq \
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
		gnupg1	
		if [ $? -eq 0 ]; then
			success "Packages install done"
		else
			error "Packages install failed"
		fi
}
################################### VDMFEC
vdmfec_install() {
	header "[ ==  VMDFEC == ]"
	apt list vdmfec > /tmp/.vdm 2>&1 || true
	if echo $(cat /tmp/.vdm) | grep -q installed; then
		warning "vdmfec is already installed"
	else
		# 64Bit change for other arm distros
		wget 'http://ftp.de.debian.org/debian/pool/main/v/vdmfec/vdmfec_1.0-2+b2_arm64.deb' && dpkg -i 'vdmfec_1.0-2+b2_arm64.deb' && rm 'vdmfec_1.0-2+b2_arm64.deb'
		apt list vdmfec > /tmp/.vdm 2>&1 || true
		if echo $(cat /tmp/.vdm) | grep -q installed; then
			success "vdmfec install done"
		else
			error "vdmfec install failed"
		fi
	fi
}
################################### Allow access, temp during dev
dev_access() {
	header "[ ==  Dev access == ]"
	if [ -d "/root/.ssh" ]; then
		warning "Folder .ssh exists"
	else
		mkdir -p /root/.ssh
		success "Folder /root/.ssh created"
	fi

	if cat /root/.ssh/authorized_keys | grep -q "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1ME48x4opi86nCvc6uT7Xz4rfhzR5/EGp24Bi/C21UOyyeQ3QBIzHSSBAVZav7I8hCtgaGaNcIGydTADqOQ8lalfYL6rpIOE3J4XyReqykLJebIjw9xXbD4uBx/2KFAZFuNybCgSXJc1XKWCIZ27jNpQUapyjsxRzQD/vC4vKtZI+XzosqNjUrZDwtAqP74Q8HMsZsF7UkQ3GxtvHgql0mlO1C/UO6vcdG+Ikx/x5Teh4QBzaf6rBzHQp5TPLWXV+dIt0/G+14EQo6IR88NuAO3gCMn6n7EnPGQsUpAd4OMwwEfO+cDI+ToYRO7vD9yvJhXgSY4N++y7FZIym+ZGz"; then
		warning "Public key exists already"
	else
		echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1ME48x4opi86nCvc6uT7Xz4rfhzR5/EGp24Bi/C21UOyyeQ3QBIzHSSBAVZav7I8hCtgaGaNcIGydTADqOQ8lalfYL6rpIOE3J4XyReqykLJebIjw9xXbD4uBx/2KFAZFuNybCgSXJc1XKWCIZ27jNpQUapyjsxRzQD/vC4vKtZI+XzosqNjUrZDwtAqP74Q8HMsZsF7UkQ3GxtvHgql0mlO1C/UO6vcdG+Ikx/x5Teh4QBzaf6rBzHQp5TPLWXV+dIt0/G+14EQo6IR88NuAO3gCMn6n7EnPGQsUpAd4OMwwEfO+cDI+ToYRO7vD9yvJhXgSY4N++y7FZIym+ZGz" > /root/.ssh/authorized_keys
		if [ $? -eq 0 ]; then
			success "Pubkey added"
		else
			error "Pubkey appending failed"
		fi
	fi
}
################################### Create user
create_user() {
	header "[ ==  Creating user == ]"
	if cat /etc/passwd | grep "$USERNAME"; then
		warning "User exists"
	else
		/usr/bin/sudo useradd -m -p $(openssl passwd -crypt "$PASSWORD") "$USERNAME" && success "User added" || error "User add failed"
	fi
}
################################### Clone git repo
git_clone_pull() {
	header "[ ==  Clone/pull git repo == ]"
	if [ -d "$GITDIR" ]; then
		#rm -r "$GITDIR"
		cd "$GITDIR" && success "Change dir to Git dir"  || error "Changing to Git dir failed"
		git pull && success "Git repository updated"  || error "Git repository update failed"
	else
		git clone "$REPO" "$GITDIR" && success "Git repository cloned" || error "Git repository failed to clone"
		chmod +x "$GITDIR"/scripts/*.sh && success "Set permission on git repository" || error "Failed to set permission on git repository"
	fi
	
	sed -i "s|source.*|source $GITDIR/lib.sh|g" "$GITDIR"/scripts/*.sh # Fix source in other scripts and speed up by not using WAN source files.
	mkdir -p "$LOCALSTORAGE"
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
	if cat /proc/cpuinfo | grep -q "Raspberry Pi 4"; then
		/bin/bash "$GITDIR"/scripts/overclock.sh && success "Overclock set, active on next reboot. Press shift during boot to disable" || error "Overclock set failed"
	fi
}
################################### GPG
gpg_keys() {
	header "[ ==  GPG keys == ]"
	if gpg1 --homedir /root/.gnupg --list-key | grep -q "${GPG_RECIPIENT}"; then
		warning "GPG key exist"
	else
		echo -e "|" "${IBlue}GPG key creation" 
		#GPG_RECIPIENT="recorder@waaromzomoeilijk.nl"
		gpg1 --homedir /root/.gnupg --list-keys

cat >keydetails <<EOF
%echo Generating a basic OpenPGP key
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
%echo done
EOF

		gpg1 --verbose --homedir /root/.gnupg --batch --gen-key keydetails

		# Set trust to 5 for the key so we can encrypt without prompt.
		echo -e "5\ny\n" |  gpg1 --homedir /root/.gnupg --verbose --command-fd 0 --expert --edit-key "${GPG_RECIPIENT}" trust;

		# Test that the key was created and the permission the trust was set.
		gpg1 --homedir /root/.gnupg --list-keys

		# Test the key can encrypt and decrypt.
		gpg1 --homedir /root/.gnupg -e -a -r "${GPG_RECIPIENT}" keydetails

		# Delete the options and decrypt the original to stdout.
		rm keydetails
		gpg1 --homedir /root/.gnupg -d keydetails.asc
		rm keydetails.asc

		if gpg1 --homedir /root/.gnupg --list-key | grep -q "${GPG_RECIPIENT}"; then
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
	
	rm -r /etc/udev/rules.d/85-usb-loader.rules
cat >> /etc/udev/rules.d/85-usb-loader.rules <<EOF
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
		echo "Install script finished on $(date)" >> "$GITDIR"/.rpi-audio-install.sh-finished
	else
		echo "Install script finished on $(date)" >> "$GITDIR"/.rpi-audio-install.sh-finished
		reboot
	fi
}
################################### Audio start recording
start_recording() {
	header "[ ==  Start recording == ]"
	echo >> "$LOG_FILE_AUDIO" ; echo "$(date)" >> "$LOG_FILE_AUDIO"
	chmod +x "$GITDIR"/scripts/*.sh && success "Set permission on git repository" || error "Failed to set permission on git repository"
	/bin/bash "$GITDIR"/scripts/audio.sh >> "$LOG_FILE_AUDIO" 2>&1
}
###################################################################### Section B: install.sh

###################################################################### Section C: audio.sh
##################################### Stop all recordings just to be sure
stop_all_recordings() {
	if pgrep 'arecord'; then
		pkill -2 'arecord' && success "SIGINT send for arecord" || fatal "Failed to SIGINT arecord" #LED/beep that mic is not detected ; sleep 10 && reboot
		#ps -cx -o pid,command | awk '$2 == "arecord" { print $1 }' | xargs kill -INT ; wait
		sleep 2
	fi

	if [ -f /tmp/.recording.lock ]; then
		rm /tmp/.recording.lock
	fi
}
##################################### In progress flag
echo "Start recording $DATE" > /tmp/.recording.lock
mountvar() {
	header "[ ==  Checking for USB drives. == ]"
	if [[ $(find /mnt -iname '.active' | sed 's|/.active||g') ]]; then
		MNTPT=$(find /mnt -iname '.active' | sed 's|/.active||g')
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
	    0) fatal "No active drive has been found, please reinsert or format USB to one of the following EXT4/FAT/NTFS" #LED/beep that mic is not detected && sleep 10 && reboot
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
		rm "$MNTPT"/.test
	else
		error "Storage is not writable, exiting."
		#LED/beep that mic is not detected
		# sleep 10 && reboot
		exit 1
	fi
}
##################################### Check free space
check_freespace_prior() {
	header "[ ==  Checking free space available on root. == ]"
	if [ "$LOCALSTORAGEUSED" -le "$MINMB" ]; then
		error "Less then $MINMB MB available on the local storage directory $LOCALSTORAGEUSED MB (Not USB)"
		#LED/beep that mic is not detected
		# sleep 10 && reboot		
	else
		success "More then $MINMB MB available on the local storage directory $LOCALSTORAGEUSED MB (Not USB)"
	fi      

	header "[ ==  Checking free space available on storage. == ]"
	if [ $USEP -ge "$MAXPCT" ]; then
		error "Drive has less then 10% storage capacity available, please free up space."
		#LED/beep that mic is not detected
		# sleep 10 && reboot
	else
		success "Drive has more then 10% capacity available, proceeding"
	fi

	if [ $(df -Ph -BM $MNTPT | tail -1 | awk '{print $4}' | sed 's|M||g') -le "$MINMB" ]; then
		fatal "Less then $MINMB MB available on usb storage directory $USEM MB (USB)"
		#LED/beep that mic is not detected
		# sleep 10 && reboot
	else
		success "More then then $MINMB MB available on usb storage directory $USEMMB (USB)"
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
	    0) fatal "No USB Microphone detected! Please plug one in now, and restart or replug USB" #LED/beep that mic is not detected ; sleep 10 && reboot
	    ;;  
	    1) success "USB Microphone detected!"
	    ;;  
	    *) fatal "More then 1 USB Mic found this is not yet supported" #LED/beep that mic is not detected ; sleep 10 && reboot
	    ;;  
	esac
}
##################################### Set volume and unmute
set_vol() {
	header "[ ==  Set volume and unmute == ]"
	amixer -q -c $CARD set Mic 80% unmute
	if [ $? -eq 0 ]; then
		success "Mic input volume set to 80% and is unmuted"
	else
		fatal "Failed to set input volume"
		#LED/beep that mic is not detected
		# sleep 10 && reboot
	fi
}
##################################### Test recording
test_rec() {
	header "[ ==  Test recording == ]"
	arecord -q -f S16_LE -d 3 -r 48000 --device="hw:$CARD,0" /tmp/test-mic.wav 
	if [ $? -eq 0 ]; then
		success "Test recording is done"
	else
		fatal "Test recording failed"
		#LED/beep that mic is not detected
		# sleep 10 && reboot		
	fi
}
##################################### Check recording file size
check_rec_filesize() {
	header "[ ==  Check if recording file size is not 0 == ]"
	if [ -s /tmp/test-mic.wav ]; then
		success "File contains data"
	else
		error "File is empty! Unable to record."
		#LED/beep that mic is not detected
		# sleep 10 && reboot		
	fi
}
##################################### Test playback
test_playback() {
	header "[ ==  Testing playback of the recording == ]"
	aplay /tmp/test-mic.wav
	if [ $? -eq 0 ]; then
		success "Playback is ok"
		rm -r /tmp/test-mic.wav
	else
		error "Playback failed"
		rm -r /tmp/test-mic.wav\
		#LED/beep that mic is not detected
		# sleep 10 && reboot		
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
##################################### Recording flow: audio-out | opusenc | gpg1 | vdmfec | split/tee
record_audio() {
	FILEDATE=$(date '+%Y-%m-%d_%H%M')
	mkdir -p "$MNTPT/$(date '+%Y-%m-%d')" && success "Created $MNTPT/$(date '+%Y-%m-%d')" || error "Failed to create $MNTPT/$(date '+%Y-%m-%d')"
	arecord -q -f S16_LE -d 0 -r 48000 --device="hw:$CARD,0" | \
	opusenc --vbr --bitrate 128 --comp 10 --expect-loss 8 --framesize 60 --title "$TITLE" --artist "$ARTIST" --date $(date +%Y-%M-%d) --album "$ALBUM" --genre "$GENRE" - - | \
	gpg1 --homedir /root/.gnupg --encrypt --recipient "${GPG_RECIPIENT}" --sign --verbose --armour --force-mdc --compress-level 0 --compress-algo none \
	     --no-emit-version --no-random-seed-file --no-secmem-warning --personal-cipher-preferences AES256 --personal-digest-preferences SHA512 \
		 --personal-compress-preferences none --cipher-algo AES256 --digest-algo SHA512 | \
	vdmfec -v -b "$BLOCKSIZE" -n 32 -k 24 | \
	tee "$MNTPT/$(date '+%Y-%m-%d')/$FILEDATE.wav.gpg" 
	clear
	sleep 3

	if [ -f "$MNTPT/$(date '+%Y-%m-%d')/$FILEDATE.wav.gpg" ]; then
		success "Recording is done"
	else
		error "Something went wrong during the recording flow"
	fi

	# Reverse Pipe
	vdmfec -d -v -b "$BLOCKSIZE" -n 32 -k 24 "$MNTPT/$(date '+%Y-%m-%d')/$FILEDATE.wav.gpg" | \
	gpg1 --homedir /root/.gnupg --decrypt > "$MNTPT/$(date '+%Y-%m-%d')/$FILEDATE.decrypted.wav"

	# SIGINT arecord - control + c equivilant. Used to end the arecord cmd and continue the pipe. Triggered when UPS mains is unplugged.
	#pkill -2 'arecord'

	# Error finding card
	# ALSA lib pcm_hw.c:1829:(_snd_pcm_hw_open) Invalid value for card

	# GPG additions
	#--passphrase-file file reads the passphrase from a file
	#--passphrase string uses string as the passphrase
	# Youll also want to add --batch, which prevents gpg from using interactive commands, and --no-tty, which makes sure that the terminal isn't used for any output.
}
###################################### Create par2 files
create_par2() {
	# Implement a last modified file check for the latest recording only
	par2 create "$MNTPT/$(date '+%Y-%m-%d')/$FILEDATE.wav.gpg.par2" "$MNTPT/$(date '+%Y-%m-%d')/$FILEDATE.wav.gpg" && success "Par2 file created" || error "Failed to create Par2 file"
}
###################################### Verify par2 files
verify_par2() {
	if [[ $(par2 verify "$MNTPT/$(date '+%Y-%m-%d')/$FILEDATE.wav.gpg.par2" | grep "All files are correct, repair is not required") ]]; then
		success "Par2 verified"
	else
		error "Par2 verification failed"
	fi
}
##################################### Check free space after recording
check_freespace() {
	header "[ ==  Checking free space available on storage after recording. == ]"
	if [ $USEP -ge "$MAXPCT" ]; then
		error "Drive has less then 10% storage capacity available, please free up space."
	else
		success "Drive has more then 10% capacity available, proceeding"
	fi

	if [ $(df -Ph -BM $MNTPT | tail -1 | awk '{print $4}' | sed 's|M||g') -le "$MINMB" ]; then
		error "Less then $MINMB MB available on usb storage directory $USEM MB (USB)"
	else
		success "More then then $MINMB MB available on usb storage directory $USEMMB (USB)"
	fi
}
##################################### Backup recordings ///// make this split
backup_recordings() {
	if [ -d "$LOCALSTORAGE" ]; then
		chown -R "$USER":"$USER" "$LOCALSTORAGE"
	else
		mkdir -p "$LOCALSTORAGE"
		chown -R "$USER":"$USER" "$LOCALSTORAGE"
	fi

	if [ "$LOCALSTORAGEUSED" -le "$MINMB" ]; then
		error "Less then $MINMB MB available on the local storage directory $LOCALSTORAGEUSED MB (Not USB)"
	else
		success "More then $MINMB MB available on the local storage directory $LOCALSTORAGEUSED MB (Not USB)"
		rsync -aAXHv "$MNTPT"/ "$LOCALSTORAGE"/
	fi      
}
##################################### Sync logs to USB
sync_to_usb() {
	mkdir -p "$MNTPT/Logs-$NAMEDATE"
	rsync -aAX /var/tmp/dietpi/logs/ "$MNTPT/Logs-$NAMEDATE/" && success "Log files synced to USB device" || warning "Log file syncing failed or had some errors, possible with rsync"
	rsync -aAX /var/log/{usb*,audio*} "$MNTPT/Logs-$NAMEDATE/" && success "Log files synced to USB device" || warning "Log file syncing failed or had some errors, possible with rsync"
}
##################################### Unmount device
unmout_device() {
	MNTPTR=$(find /mnt -iname '.active' | sed 's|/Recordings/.active||g')
	sync ; sleep 3 ; echo 
	systemd-umount "$MNTPTR"
	if [ $? -eq 0 ]; then
		success "Systemd-unmount done"
		# Remove folder after unmount
		sleep 2
		rmdir "$MNTPTR" && success "$MNTPTR folder removed" || error "$MNTPTR folder remove failed"
	else
		error "Systemd-umount failed"
		umount -l "$MNTPTR" && success "umount -l done" || error "Umount -l - Not mounted double check, done"
		#systemctl disable "$MOUNT_DIR-$DEVICE".mount && success "Systemctl disabled $MOUNT_DIR-$DEVICE.mount done" || error "Systemctl disabled $MOUNT_DIR-$DEVICE.mount failed"
		#systemctl daemon-reload && success "Systemctl daemon-reload done" || error "Systemctl daemon-reload failed"
		#systemctl reset-failed && success "Systemctl reset-failed done" || error "Systemctl reset-failed failed"
		# Remove folder after unmount
		sleep 2
		rmdir "$MNTPTR" && success "$MNTPTR folder removed" || error "$MNTPTR folder remove failed"
	fi	

	# test that this device has disappeared from mounted devices
	device_mounted=$(grep -q "$DEV" /etc/mtab)
	if [ "$device_mounted" ]; then
		error "Failed to Un-Mount, forcing umount -l"
		echo "temp disable of unmount for dev"
		umount -l "/dev/$DEVICE" && success "umount -l done" || error "Umount -l - Not mounted double check, done"
		if [ $? -eq 0 ]; then
			rm -f "$MNTPTR" && success "$MNTPTR folder removed" || error "$MNTPTR folder remove failed"
		fi
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
		echo -e "${IYellow}Fail2ban is already installed${Color_Off}" >&2
	else
		apt-get install fail2ban -y -qq

		wget -O /etc/fail2ban/jail.local https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/static/jail.local

		systemctl restart fail2ban

		if [ "$FB" == "install ok installed" ]; then
			echo -e "|" "${IGreen}Fail2ban install - Done${Color_Off} |" >&2
		else
			echo -e "|" "${IRed}Fail2ban install - Failed${Color_Off} |" >&2
		fi
	fi

	if [ "$UFWSTATUS" == "ERROR: Couldn't determine iptables version" ]; then
		update-alternatives --set iptables /usr/sbin/iptables-legacy && success "Fixed iptables issue with UFW. Next reboot will set firewall rules" || error "Failed to fix iptables issue with UFW"
	#elif [ "$UFWSTATUS" == "ERROR: problem running iptables: iptables v1.8.7 (legacy): can't initialize iptables table `filter': Table does not exist (do you need to insmod?)
	#Perhaps iptables or your kernel needs to be upgraded." ]; then
	#        warning "We need a reboot in order to use UFW with iptables"
	else
	echo "y" | ufw reset
	ufw default allow outgoing
	ufw default deny incoming
	ufw limit 22/tcp
	echo "y" | ufw enable
	fi
}
###################################################################### Section D: hardening

###################################################################### Section E: Overclock
overclock_rpi() {
	# No core freq changes for RPI4 
	# https://www.raspberrypi.org/documentation/configuration/config-txt/overclocking.md
	# https://elinux.org/RPiconfig

	CONFIG="/boot/config.txt"

	sed -i '/arm_freq=/d' "$CONFIG"
	sed -i '/arm_freq_min=/d' "$CONFIG"
	sed -i '/over_voltage=/d' "$CONFIG"
	sed -i '/over_voltage_min=/d' "$CONFIG"
	sed -i '/temp_limit=/d' "$CONFIG"
	sed -i '/initial_turbo=/d' "$CONFIG"
	sed -i '/core_freq/d' "$CONFIG"
	sed -i '/sdram_freq/d' "$CONFIG"
	sed -i '/-------Overclock-------/d' "$CONFIG"

# Dynamic overclock config
cat >> "$CONFIG" <<EOF
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
    sleep 2
 
	# Fix, disable leftover systemd mounts
	systemctl disable "mnt-$DEVICE.mount" && success 'systemctl disable "mnt-$DEVICE.mount"' || warning 'systemctl disable "mnt-$DEVICE.mount" failed, probably did not exist'
	systemctl daemon-reload 

	# Check and clear old mountpoint
    is_mounted "$DEVICE" && fatal "seems /dev/$DEVICE is already mounted"

	if [ -d "$MOUNT_DIR/$DEVICE" ]; then
		rmdir "$MOUNT_DIR/$DEVICE"  
	fi


    # test mountpoint - it shouldn't exist
    [ -e "$MOUNT_DIR/$DEVICE" ] && fatal "It seems mountpoint $MOUNT_DIR/$DEVICE already exists"

    # make the mountpoint
    mkdir "$MOUNT_DIR/$DEVICE" && success "Mountpoint $MOUNT_DIR/$DEVICE created" || fatal "Mountpoint $MOUNT_DIR/$DEVICE creation failed"

    # make sure the user owns this folder
    chown -R "$USER":"$USER" "$MOUNT_DIR/$DEVICE" && success "Chown $USER:$USER on $MOUNT_DIR/$DEVICE set" || fatal "Chown $USER:$USER on $MOUNT_DIR/$DEVICE failed"

    # mount the device base on USB file system
    case "$FILESYSTEM" in
        vfat) systemd-mount -t vfat -o utf8,uid="$USER",gid="$USER" "/dev/$DEVICE" "$MOUNT_DIR/$DEVICE" || fatal "Failed mounting VFAT parition"
              ;;
        ntfs) systemd-mount -t auto -o uid="$USER",gid="$USER",locale=en_US.UTF-8 "/dev/$DEVICE" "$MOUNT_DIR/$DEVICE" || fatal "Failed mounting NTFS partition" 
              ;;
        ext*) systemd-mount -t auto -o sync,noatime "/dev/$DEVICE" "$MOUNT_DIR/$DEVICE" || fatal "Failed mounting EXT partition"
              ;;	
     esac

    is_mounted "$DEVICE" && success "Mount OK" || fatal "Unable to mount, please check the logs"
} 
#################################### Auto Start Function
autostart() {
    header "[ ==  USB Auto Start Program == ]"
    DEV=$(echo "$DEVICE" | cut -c -3)
    # Check # of partitions
    if [[ $(grep -c "$DEV"'[0-9]' /proc/partitions) -gt 1 ]]; then
        fatal "More then 1 parition detected, please format your drive and create a single FAT32/NTFS/EXT partition and try again"
    elif [[ $(grep -c "$DEV"'[0-9]' /proc/partitions) -eq 0 ]]; then
        fatal "No parition detected, please format your drive and create a single FAT32/NTFS/EXT partition and try again"
    elif [[ $(grep -c "$DEV"'[0-9]' /proc/partitions) -eq 1 ]]; then
        success "1 partition detected, checking if its been used before"
        # Check if drive is empty
        if [ -f "$(ls -I '.Trash*' -A "$MOUNT_DIR/$DEVICE")" ]; then
            # Empty
            warning "EMPTY"
            mkdir "$MOUNT_DIR/$DEVICE/Recordings" && success "Created $MOUNT_DIR/$DEVICE/Recordings" || error "Failed to create $MOUNT_DIR/$DEVICE/Recordings"
            echo "$MOUNT_DIR/$DEVICE $DEVID $DATE" >> "$MOUNT_DIR/$DEVICE/Recordings/.active" && success "Written device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active" || error "Failed to write device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active"
            chown -R "$USER":"$USER" "$MOUNT_DIR/$DEVICE" && success "Set permissions on $MOUNT_DIR/$DEVICE" || error "Set permissions on $MOUNT_DIR/$DEVICE failed"
            # Temporary export GPG keys to storage device.
            mkdir "$MOUNT_DIR/$DEVICE/DevGnupg" && success "Created temp dev gnupg folder" || error "Failed to create temp dev gnupg folder"
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
                if [ -d "$MOUNT_DIR/$DEVICE"/DevGnupg ]; then
                    warning "Temporary Dev GPG key folder is populated already, skipping" 
                else
                    echo "Temporary Dev GPG key folder is empty, copying"
                    # Temporary export GPG keys to storage device.
                    mkdir "$MOUNT_DIR/$DEVICE/DevGnupg" && success "Created temp dev gnupg folder" || error "Failed to create temp dev gnupg folder, probably exists already."
                    gpg1 --export-ownertrust > "$MOUNT_DIR/$DEVICE/DevGnupg/otrust.txt"
                    gpg1 -a --export-secret-keys > "$MOUNT_DIR/$DEVICE/DevGnupg/privatekey.asc"
                    gpg1 -a --export > "$MOUNT_DIR/$DEVICE/DevGnupg/publickey.asc"					
                fi
            else
                # No
                echo
                mkdir "$MOUNT_DIR/$DEVICE/Recordings" && success "Created $MOUNT_DIR/$DEVICE/Recordings" || error "Failed to create $MOUNT_DIR/$DEVICE/Recordings, probably exists already."
                echo "$MOUNT_DIR/$DEVICE $DEVID $DATE" >> "$MOUNT_DIR/$DEVICE/Recordings/.active" && success "Written device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active" || error "Failed to write device ID, mountpoint and date to $MOUNT_DIR/$DEVICE/Recordings/.active"
                chown -R "$USER":"$USER" "$MOUNT_DIR/$DEVICE" && success "Set permissions on $MOUNT_DIR/$DEVICE" || error "Set permissions on $MOUNT_DIR/$DEVICE failed"
                # Temporary export GPG keys to storage device.
                mkdir "$MOUNT_DIR/$DEVICE/DevGnupg" && success "Created temp dev gnupg folder" || error "Failed to create temp dev gnupg folder, probably exists already."
                gpg1 --export-ownertrust > "$MOUNT_DIR/$DEVICE/DevGnupg/otrust.txt"
                gpg1 -a --export-secret-keys > "$MOUNT_DIR/$DEVICE/DevGnupg/privatekey.asc"
                gpg1 -a --export > "$MOUNT_DIR/$DEVICE/DevGnupg/publickey.asc"
            fi
        fi
    fi
    # Start audio recording
    header "[ ==  Start recording == ]"
    echo >> "$LOG_FILE_AUDIO" ; echo "$(date)" >> "$LOG_FILE_AUDIO"
    /bin/bash "$GITDIR"/scripts/audio.sh >> "$LOG_FILE_AUDIO" 2>&1
}
###################################################################### Section F: auto-start program

###################################################################### Section G: usb-unloader.sh
autounload() {
	header "[ ==  USB UnLoader == ]" 
	[ "$MOUNT_DIR" ] || fatal "Failed to supply Mount Dir parameter"
	[ "$DEVICE" ] || fatal "Failed to supply DEVICE parameter"

	if [ -d "$MOUNT_DIR/$DEVICE" ]; then
		systemd-umount "$MOUNT_DIR/$DEVICE" && success "Systemd-unmounted succeeded" || warning "Systemd-unmounted failed, probably did not exist"
		systemctl disable "mnt-$DEVICE.mount" && success 'systemctl disable "mnt-$DEVICE.mount"' || warning 'systemctl disable "mnt-$DEVICE.mount" failed, probably did not exist'
		systemctl daemon-reload 
		umount "$MOUNT_DIR/$DEVICE" && success "Unmount succeeded" || warning "Unmounting failed, probably did not exist"
		umount -l "$MOUNT_DIR/$DEVICE" && success "Unmounted -l succeeded" || warning "Unmounting -l failed, probably did not exist"
		rmdir "$MOUNT_DIR/$DEVICE" && success "Removed directory $MOUNT_DIR/$DEVICE" || error "Directory removal of $MOUNT_DIR/$DEVICE failed, probably did not exist"
		rmdir "$DEVICE"/sd*
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
###################################################################### Section H: Bash colors
