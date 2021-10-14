#!/bin/bash
# Installation script for an automated audio recorder on a RaspberryPI4 running DietPI
# info@waaromzomoeilijk.nl
# login root/dietpi

# Version
# v0.0.9

################################### Variables & functions
source <(curl -sL https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/lib.sh)

###################################  Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

###################################  Check if script runs as root
root_check
clear
################################### Prefer IPv4 for apt
echo ; echo -e "|" "${IBlue}IPv4 APT Preference - $DATE${Color_Off} |" >&2 ; echo
if [ -f /etc/apt/apt.conf.d/99force-ipv4 ]; then
	echo -e "|" "${IYellow}IPv4 Preference already set${Color_Off} |" >&2
else
	echo 'Acquire::ForceIPv4 "true";' >> /etc/apt/apt.conf.d/99force-ipv4
	if [ $? -eq 0 ]; then
		echo -e "|" "${IGreen}Set IPv4 Preference - Done${Color_Off} |" >&2
	else
		echo -e "|" "${IRed}Set IPv4 Preference - Failed${Color_Off} |" >&2
	fi
fi

################################### Upstart
echo ; echo -e "|" "${IBlue}Setting up rc.local${Color_Off} |" >&2 ; echo

if [ -f "/etc/rc.local" ]; then
      mv /etc/rc.local /etc/rc.local.backup
fi

if [ -f /etc/rc.local ]; then
	mv /etc/rc.local /etc/rc.local.backup
else
	systemctl disable rc-local.service || true
	rm /etc/systemd/system/rc-local.service
	systemctl daemon-reload
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
/bin/bash "$GITDIR/install.sh" >> "$LOG_FILE_INSTALL" 2>&1&
exit 0
EOF

	chmod +x /etc/rc.local
	systemctl daemon-reload
	systemctl enable rc-local.service
	systemctl start rc-local.service
	
	if [ -f /etc/rc.local ]; then
		# Check if the above is succesfull
		if cat /etc/rc.local | grep -q "$GITDIR/install.sh"; then
			echo ; echo -e "|" "${IGreen}Setting up rc.local - Created${Color_Off} |" >&2
		else
			echo ; echo -e "|" "${IRed}Setting up rc.local - Failed, file exists but not the proper content${Color_Off} |" >&2
		fi
	else
		echo ; echo -e "|" "${IRed}Setting up rc.local - Failed${Color_Off} |" >&2
	fi
	

fi

#################################### Update
echo ; echo -e "|     " "${IBlue}Update: OS ${Color_Off}      |" >&2 ; echo
export "DEBIAN_FRONTEND=noninteractive"
export "DEBIAN_PRIORITY=critical"
echo -e "|"  "${IBlue}Auto clean${Color_Off} |" >&2
apt_autoclean & spinner
echo ; echo -e "|"  "${IBlue}Auto purge${Color_Off} |" >&2
apt_autoremove & spinner
echo ; echo -e "|"  "${IBlue}Update${Color_Off} |" >&2
apt_update & spinner
echo ; echo -e "|"  "${IBlue}Upgrade${Color_Off} |" >&2
apt_upgrade & spinner

################################### Dependencies
echo ; echo -e "|" "${IBlue}Dependancies${Color_Off} |" >&2
apt-get install -y -qq -o=Dpkg::Use-Pty=0 \
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
	ufw
	if [ $? -eq 0 ]; then
		echo ; echo -e "|" "${IGreen}Packages install - Done${Color_Off} |" >&2
	else
		echo ; echo -e "|" "${IRed}Packages install - Failed${Color_Off} |" >&2
	fi	
#	gpgv1
#  	zerotier
#	autossh \
#	raspberrypi-kernel-headers \

################################### VDMFEC
echo ; echo -e "|" "${IBlue}VMDFEC${Color_Off} |" >&2 ; echo
apt list vdmfec > /tmp/.vdm 2>&1 || true
if echo $(cat /tmp/.vdm) | grep -q installed; then
	echo -e "|" "${IYellow}vdmfec is already installed${Color_Off} |" >&2
else
	# 64Bit change for other arm distros
	wget http://ftp.de.debian.org/debian/pool/main/v/vdmfec/vdmfec_1.0-2+b2_arm64.deb && dpkg -i vdmfec_1.0-2+b2_arm64.deb && rm vdmfec_1.0-2+b2_arm64.deb
	apt list vdmfec > /tmp/.vdm 2>&1 || true
	if echo $(cat /tmp/.vdm) | grep -q installed; then
		echo ; echo -e "|" "${IGreen}vdmfec install - Done${Color_Off} |" >&2
	else
		echo ; echo -e "|" "${IRed}vdmfec install - Failed${Color_Off} |" >&2
	fi
fi

################################### Set timezone based upon WAN ip
echo ; echo -e "|" "${IBlue}Set timezone based on WAN IP${Color_Off} |" >&2 ; echo

timedatectl set-timezone Europe/Amsterdam &>/tmp/.tz || true
if echo $(cat /tmp/.tz) | grep -q "Failed to connect to bus: No such file or directory"; then
        echo -e "|" "${IYellow}Timezone set - Failed (first install fails because of dbus dependency. Next run will set the timezone automatically) ${Color_Off} |" >&2
else
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
fi

################################### Allow access, temp during dev
echo ; echo -e "|" "${IBlue}Dev access${Color_Off} |" >&2 ; echo
if [ -d "/root/.ssh" ]; then
	echo -e "|" "${IGreen}Folder .ssh exists!${Color_Off} |" >&2
else
	mkdir -p /root/.ssh
	echo -e "|" "${IGreen}Folder /root/.ssh created!${Color_Off} |" >&2
fi

if cat /root/.ssh/authorized_keys | grep -q "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1ME48x4opi86nCvc6uT7Xz4rfhzR5/EGp24Bi/C21UOyyeQ3QBIzHSSBAVZav7I8hCtgaGaNcIGydTADqOQ8lalfYL6rpIOE3J4XyReqykLJebIjw9xXbD4uBx/2KFAZFuNybCgSXJc1XKWCIZ27jNpQUapyjsxRzQD/vC4vKtZI+XzosqNjUrZDwtAqP74Q8HMsZsF7UkQ3GxtvHgql0mlO1C/UO6vcdG+Ikx/x5Teh4QBzaf6rBzHQp5TPLWXV+dIt0/G+14EQo6IR88NuAO3gCMn6n7EnPGQsUpAd4OMwwEfO+cDI+ToYRO7vD9yvJhXgSY4N++y7FZIym+ZGz"; then
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
echo ; echo -e "|" "${IBlue}Creating user${Color_Off} |" >&2 ; echo
if cat /etc/passwd | grep "$USERNAME"; then
	echo ; echo -e "|" "${IGreen}User exists!${Color_Off} |" >&2
else
	/usr/bin/sudo useradd -m -p $(openssl passwd -crypt "$PASSWORD") "$USERNAME"
	if [ $? -eq 0 ]; then
		echo -e "|" "${IGreen}User added!${Color_Off} |" >&2
	else
		echo -e "|" "${IRed}User add failed!${Color_Off} |" >&2
	fi
fi

################################### Clone git repo
echo ; echo -e "|" "${IBlue}Clone git repo${Color_Off} |" >&2 ; echo
if [ -d "$GITDIR" ]; then
	#cd "$GITDIR"
	#git pull
	rm -r "$GITDIR"
	if [ $? -eq 0 ]; then
		echo ; echo -e "|" "${IGreen}Git repository removed!${Color_Off} |" >&2 ; echo 
	else
		echo ; echo -e "|" "${IRed}Git repository failed to remove!${Color_Off} |" >&2 ; echo
	fi

	git clone "$REPO" "$GITDIR"
	chmod +x "$GITDIR"/scripts/*.sh
	if [ $? -eq 0 ]; then
		echo ; echo -e "|" "${IGreen}Git repository cloned!${Color_Off} |" >&2
	else
		echo ; echo -e "|" "${IRed}Git repository failed to clone!${Color_Off} |" >&2
	fi
else
	git clone "$REPO" "$GITDIR"
	chmod +x "$GITDIR"/scripts/*.sh
	if [ $? -eq 0 ]; then
		echo ; echo -e "|" "${IGreen}Git repository cloned!${Color_Off} |" >&2
	else
		echo ; echo -e "|" "${IRed}Git repository failed to clone!${Color_Off} |" >&2
	fi
fi

################################### Hardening
echo ; echo -e "|" "${IBlue}Hardening${Color_Off} |" >&2 ; echo
/bin/bash "$GITDIR"/scripts/hardening.sh
if [ $? -eq 0 ]; then
	echo ; echo -e "|" "${IGreen}Hardening executed!${Color_Off} |" >&2
else
	echo ; echo -e "|" "${IRed}Hardening failed!${Color_Off} |" >&2
fi

################################### Dynamic overclock
# Please at minimum add some heat sinks to the RPI. Better to also add a FAN. thermal throtteling is in place at 75 celcius 
# Overclocking dynamically will only affect the temp on high load for longer periods. You can mitigate that with above.
echo ; echo -e "|" "${IBlue}Overclock${Color_Off} |" >&2 ; echo
if cat /proc/cpuinfo | grep -q "Raspberry Pi 4"; then
	/bin/bash "$GITDIR"/scripts/overclock.sh
	if [ $? -eq 0 ]; then
		echo -e "|" "${IGreen}Overclock set, active on next reboot. Press shift during boot to disable!${Color_Off} |" >&2
	else
		echo -e "|" "${IRed}Overclock set failed!${Color_Off} |" >&2
	fi
fi

################################### Storage, add auto mount & checks for usb drives
echo ; echo -e "|" "${IBlue}Storage${Color_Off} |" >&2 ; echo
if [ -f "/etc/udev/rules.d/85-usb-loader.rules" ]; then
	echo -e "|"  "${IYellow}/etc/udev/rules.d/85-usb-loader.rules exists${Color_Off} |" >&2
else

cat >> /etc/udev/rules.d/85-usb-loader.rules <<EOF
ACTION=="add", KERNEL=="sd*[0-9]", SUBSYSTEMS=="usb", RUN+="$GITDIR/scripts/usb-initloader.sh ADD %k $env{ID_FS_TYPE}"
ACTION=="remove", KERNEL=="sd*[0-9]", SUBSYSTEMS=="usb", RUN+="$GITDIR/scripts/usb-initloader.sh %k"
EOF

	udevadm control --reload-rules && echo -e "|" "${IGreen}Storage automation has been setup!${Color_Off} |" >&2 || echo -e "|" "${IGreen}Storage automation setup has failed!${Color_Off} |" >&2
fi

################################### UPS
#echo ; echo -e "|" "${IBlue}UPS${Color_Off} |" >&2 ; echo
#/bin/bash "$GITDIR"/scripts/ups.sh

################################### ZeroTier
#echo ; echo -e "|" "${IBlue}Zerotier/networking${Color_Off} |" >&2 ; echo
#/bin/bash "$GITDIR"/scripts/zerotier.sh

################################### LED / Buttons
#echo ; echo -e "|" "${IBlue}LED/buttons${Color_Off} |" >&2 ; echo
#/bin/bash "$GITDIR"/scripts/ph.sh

################################### Audio recording
echo ; echo -e "|" "${IBlue}Audio${Color_Off} |" >&2 ; echo
echo -e "|" "${IBlue}Audio recording${Color_Off} |" > "$LOG_FILE_AUDIO"
/bin/bash "$GITDIR"/scripts/audio.sh >> "$LOG_FILE_AUDIO" 2>&1&

#exit 0
