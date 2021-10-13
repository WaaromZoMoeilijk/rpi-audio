#!/bin/bash
# Installation script for an automated audio recorder on a RaspberryPI4 running DietPI
# info@waaromzomoeilijk.nl
# login root/dietpi

#echo -e "|"  "${IGreen} ${Color_Off} |"
#echo -e "|"  "${IRed} ${Color_Off} |" >&2

# Version
# v0.1

################################### Variables & functions
source <(curl -sL https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/lib.sh)

###################################  Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=1
debug_mode

###################################  Check if script runs as root
root_check

################################### Prefer IPv4 for apt
if [ -f /etc/apt/apt.conf.d/99force-ipv4 ]; then
	echo "IPv4 Preference already set"
else
	echo 'Acquire::ForceIPv4 "true";' >> /etc/apt/apt.conf.d/99force-ipv4
fi 

#################################### Update
export "DEBIAN_FRONTEND=noninteractive"
export "DEBIAN_PRIORITY=critical"
clear ; echo "Auto clean"
apt_autoclean & spinner
clear ; echo "Auto remove"
apt_autoremove & spinner
clear ; echo "Update"
apt_update & spinner
clear ; echo "Upgrade"
apt_upgrade & spinner

################################### Dependencies
clear ; echo "Install Dependencies"
apt install -y \
	git \
  	jq \
	nano \
	curl \
	unattended-upgrades \
	net-tools \
	alsa-utils \
	opus-tools 
#	gpgv1 
#  	zerotier
#	autossh \
#	raspberrypi-kernel-headers \	
	
################################### VDMFEC
if apt list vdmfec | grep -q installed; then
	echo "vdmfec already installed"
else
	# 64Bit change for other arm distros
	wget http://ftp.de.debian.org/debian/pool/main/v/vdmfec/vdmfec_1.0-2+b2_arm64.deb && dpkg -i vdmfec_1.0-2+b2_arm64.deb && rm vdmfec_1.0-2+b2_arm64.deb
fi

################################### Set timezone based upon WAN ip 
clear ; echo "Set timezone based on WAN IP"
if curl -sL 'ip-api.com/json' | grep -q "404"; then
	curl -s --location --request GET 'https://api.ipgeolocation.io/timezone?apiKey=bbebedbbace2445386c258c0a472df1c' | jq '.timezone' | xargs timedatectl set-timezone
	if [ $? -eq 0 ]; then
		echo -e "|" "${IGreen}Timezone set!${Color_Off} |" >&2
	else
		echo -e "|" "${IRed}Timezone set failed!${Color_Off} |" >&2
	fi	
else
	curl -sL 'ip-api.com/json' | jq '.timezone' | xargs timedatectl set-timezone
	if [ $? -eq 0 ]; then
		echo -e "|" "${IGreen}Timezone set!${Color_Off} |" >&2
	else
		echo -e "|" "${IRed}Timezone set failed!${Color_Off} |" >&2
	fi
fi

################################### Allow root access, temp during dev
if [ -d "/root/.ssh" ]; then
	echo -e "|" "${IGreen}Folder .ssh exists!${Color_Off} |" >&2
else
	mkdir -p /root/.ssh
	echo -e "|" "${IGreen}Folder /root/.ssh created!${Color_Off} |" >&2	
fi

if cat /root/.ssh/autorized_keys | grep -q "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1ME48x4opi86nCvc6uT7Xz4rfhzR5/EGp24Bi/C21UOyyeQ3QBIzHSSBAVZav7I8hCtgaGaNcIGydTADqOQ8lalfYL6rpIOE3J4XyReqykLJebIjw9xXbD4uBx/2KFAZFuNybCgSXJc1XKWCIZ27jNpQUapyjsxRzQD/vC4vKtZI+XzosqNjUrZDwtAqP74Q8HMsZsF7UkQ3GxtvHgql0mlO1C/UO6vcdG+Ikx/x5Teh4QBzaf6rBzHQp5TPLWXV+dIt0/G+14EQo6IR88NuAO3gCMn6n7EnPGQsUpAd4OMwwEfO+cDI+ToYRO7vD9yvJhXgSY4N++y7FZIym+ZGz"; then
	echo -e "|" "${IGreen}Public key exists already!${Color_Off} |" >&2
else
	echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1ME48x4opi86nCvc6uT7Xz4rfhzR5/EGp24Bi/C21UOyyeQ3QBIzHSSBAVZav7I8hCtgaGaNcIGydTADqOQ8lalfYL6rpIOE3J4XyReqykLJebIjw9xXbD4uBx/2KFAZFuNybCgSXJc1XKWCIZ27jNpQUapyjsxRzQD/vC4vKtZI+XzosqNjUrZDwtAqP74Q8HMsZsF7UkQ3GxtvHgql0mlO1C/UO6vcdG+Ikx/x5Teh4QBzaf6rBzHQp5TPLWXV+dIt0/G+14EQo6IR88NuAO3gCMn6n7EnPGQsUpAd4OMwwEfO+cDI+ToYRO7vD9yvJhXgSY4N++y7FZIym+ZGz" > /root/.ssh/authorized_keys
	if [ $? -eq 0 ]; then
		echo -e "|" "${IGreen}Pubkey added!${Color_Off} |" >&2
	else
		echo -e "|" "${IRed}Pubkey appending failed!${Color_Off} |" >&2
	fi
fi

################################### Create user
#clear ; echo "Creating user"
#if cat /etc/passwd | grep "$USERNAME"; then
#	echo -e "|" "${IGreen}User exists!${Color_Off} |" >&2
#else
	#/usr/bin/sudo useradd -m -p $(openssl passwd -crypt "$PASSWORD") "$USERNAME"
	#if [ $? -eq 0 ]; then
	#	echo -e "|" "${IGreen}User added!${Color_Off} |" >&2
	#else
	#	echo -e "|" "${IRed}User add failed!${Color_Off} |" >&2
	#fi
#fi

################################### Clone git repo
clear ; echo "Clone git repo"
if [ -d "$GITDIR" ]; then
	rm -r "$GITDIR" # Only during dev
	#cd "$GITDIR"
	#git pull
	if [ $? -eq 0 ]; then
		echo -e "|" "${IGreen}Git repository updated!${Color_Off} |" >&2
	else
		echo -e "|" "${IRed}Git repository failed to update!${Color_Off} |" >&2
	fi
else
	git clone "$REPO" "$GITDIR"
	if [ $? -eq 0 ]; then
		echo -e "|" "${IGreen}Git repository cloned!${Color_Off} |" >&2
	else
		echo -e "|" "${IRed}Git repository failed to clone!${Color_Off} |" >&2
	fi	
fi

################################### Hardening
#clear ; echo "Hardening"
#/bin/bash "$GITDIR"/scripts/hardening.sh

################################### Dynamic overclock
#clear ; echo "Overclock"
#if cat /proc/cpuinfo | grep -q "Raspberry Pi 4"; then
#    /bin/bash "$GITDIR"/scripts/overclock.sh
#fi

################################### Storage
# Add auto mount & checks for usb drives
if [ -f "/etc/udev/rules.d/85-usb-loader.rules" ]; then
	echo -e "|"  "${IGreen}/etc/udev/rules.d/85-usb-loader.rules exists${Color_Off} |" >&2
else
cat >> /etc/udev/rules.d/85-usb-loader.rules <<EOF
ACTION=="add", KERNEL=="sd*[0-9]", SUBSYSTEMS=="usb", RUN+="$GITDIR/scripts/usb-initloader.sh ADD %k $env{ID_FS_TYPE}"
ACTION=="remove", KERNEL=="sd*[0-9]", SUBSYSTEMS=="usb", RUN+="$GITDIR/scripts/usb-initloader.sh %k"
EOF

	udevadm control --reload-rules

	echo -e "|" "${IGreen}Storage automation has been setup!${Color_Off} |" >&2
fi

################################### UPS
#/bin/bash "$GITDIR"/scripts/ups.sh

################################### ZeroTier
#/bin/bash "$GITDIR"/scripts/zerotier.sh

################################### LED / Buttons
#/bin/bash "$GITDIR"/scripts/ph.sh

################################### Audio recording
#/bin/bash "$GITDIR"/scripts/audio.sh
# Setup mechanism to start on boot or only on USB insert

clear

exit 0
