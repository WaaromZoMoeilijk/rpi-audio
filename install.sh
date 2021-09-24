#!/bin/bash
# Installation script for an automated audio recorder on a RaspberryPI4 running DietPI
# info@waaromzomoeilijk.nl
# login root/dietpi

#echo -e "|"  "${IGreen} ${Color_Off} |"
#echo -e "|"  "${IRed} ${Color_Off} |" >&2

# Version
# v0.1
 exit 0
################################### Variables & functions
source <(curl -sL https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/lib.sh)

# Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=1
debug_mode

# Check if script runs as root
root_check

################################### Prefer IPv4 for apt
echo 'Acquire::ForceIPv4 "true";' >> /etc/apt/apt.conf.d/99force-ipv4

# Update
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
#	autossh \
#	raspberrypi-kernel-headers \
	unattended-upgrades \
	net-tools \
	alsa-utils \
  	#zerotier

################################### Check ZFS 
# only works after a reboot
#modprobe zfs
#if zpool status | grep -q "no pools available"; then
#	echo -e "|"  "${IGreen}ZFS installed and works! ${Color_Off} |"
#else
#	echo -e "|"  "${IRed}ZFS installation failed! ${Color_Off} |" >&2
#fi

################################### Set timezone based upon WAN ip 
clear ; echo "Set timezone based on WAN IP"
if curl -sL 'ip-api.com/json' | grep -q "404"; then
	echo -e "|"  "${IRed}Site is down, set timezone manually after installation with: sudo curl -sL 'ip-api.com/json' | jq '.timezone' | xargs timedatectl set-timezone ${Color_Off} |" >&2
else
	curl -sL 'ip-api.com/json' | jq '.timezone' | xargs timedatectl set-timezone
fi

# unattended-upgrades
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure unattended-upgrades

################################### Allow root access, temp during dev
mkdir -p /root/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1ME48x4opi86nCvc6uT7Xz4rfhzR5/EGp24Bi/C21UOyyeQ3QBIzHSSBAVZav7I8hCtgaGaNcIGydTADqOQ8lalfYL6rpIOE3J4XyReqykLJebIjw9xXbD4uBx/2KFAZFuNybCgSXJc1XKWCIZ27jNpQUapyjsxRzQD/vC4vKtZI+XzosqNjUrZDwtAqP74Q8HMsZsF7UkQ3GxtvHgql0mlO1C/UO6vcdG+Ikx/x5Teh4QBzaf6rBzHQp5TPLWXV+dIt0/G+14EQo6IR88NuAO3gCMn6n7EnPGQsUpAd4OMwwEfO+cDI+ToYRO7vD9yvJhXgSY4N++y7FZIym+ZGz" > /root/.ssh/authorized_keys

# Create user
#/usr/bin/sudo useradd -m -p $(openssl passwd -crypt "$PASSWORD") "$USERNAME"

################################### Clone git repo
clear ; echo "Clone git repo"
if [ -d "$GITDIR" ]; then
  rm -r "$GITDIR"
fi

git clone "$REPO" "$GITDIR"

################################### Hardening
#clear ; echo "Hardening"
#/bin/bash "$GITDIR"/scripts/hardening.sh

################################### Overclock
#clear ; echo "Overclock"
#if cat /proc/cpuinfo | grep -q "Raspberry Pi 4"; then
#    /bin/bash "$GITDIR"/scripts/overclock.sh
#fi

################################### Audio recording
#/bin/bash "$GITDIR"/scripts/audio.sh

################################### Storage
# Add auto mount & checks for usb drives
cat >> /etc/udev/rules.d/85-usb-loader.rules <<EOF
ACTION=="add", KERNEL=="sd*[0-9]", SUBSYSTEMS=="usb", RUN+="$GITDIR/scripts/usb-initloader.sh ADD %k $env{ID_FS_TYPE}"
ACTION=="remove", KERNEL=="sd*[0-9]", SUBSYSTEMS=="usb", RUN+="$GITDIR/scripts/usb-initloader.sh %k"
EOF

udevadm control --reload-rules

################################### UPS
#/bin/bash "$GITDIR"/scripts/ups.sh

################################### ZeroTier
#/bin/bash "$GITDIR"/scripts/zerotier.sh

################################### LED / Buttons
#/bin/bash "$GITDIR"/scripts/ph.sh

clear

exit 0
