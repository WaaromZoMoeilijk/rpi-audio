#!/bin/bash
# Installation script for an automated audio recorder on a RaspberryPI4 running DietPI
# info@waaromzomoeilijk.nl
# login root/dietpi

# Version
# v0.0.9

################################### Variables & functions
source <(curl -sL https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/lib.sh) ; wait

###################################  Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

###################################  Check if script runs as root
root_check
clear

################################### Prefer IPv4 for apt
header "IPv4 APT Preference - $DATE"
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

################################### Upstart
header "Setting up rc.local"
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
		echo ; success "Setting up rc.local - Created"
	else
		echo ; error "Setting up rc.local failed, file exists but not the proper content"
	fi
else
	echo ; error "Setting up rc.local failed"
fi


################################### Set timezone based upon WAN ip
header "Set timezone based on WAN IP"
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

#################################### Update
header "Update: OS"
export "DEBIAN_FRONTEND=noninteractive"
export "DEBIAN_PRIORITY=critical"
header "Auto clean"
#apt_autoclean & spinner
header "Auto purge"
#apt_autoremove & spinner
header "Update"
#apt_update & spinner
header "Upgrade"
#apt_upgrade & spinner

################################### Dependencies
header "Dependencies"
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
		echo ; success "Packages install done"
	else
		echo ; error "Packages install failed"
	fi	

################################### VDMFEC
#header "VMDFEC"
apt list vdmfec > /tmp/.vdm 2>&1 || true
if echo $(cat /tmp/.vdm) | grep -q installed; then
	warning "vdmfec is already installed"
else
	# 64Bit change for other arm distros
	wget 'http://ftp.de.debian.org/debian/pool/main/v/vdmfec/vdmfec_1.0-2+b2_arm64.deb' && dpkg -i 'vdmfec_1.0-2+b2_arm64.deb' && rm 'vdmfec_1.0-2+b2_arm64.deb'
	apt list vdmfec > /tmp/.vdm 2>&1 || true
	if echo $(cat /tmp/.vdm) | grep -q installed; then
		echo ; success "vdmfec install done"
	else
		echo ; error "vdmfec install failed"
	fi
fi

################################### Allow access, temp during dev
header "Dev access"
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

################################### Create user
header "Creating user"
if cat /etc/passwd | grep "$USERNAME"; then
	echo ; warning "User exists"
else
	/usr/bin/sudo useradd -m -p $(openssl passwd -crypt "$PASSWORD") "$USERNAME" && success "User added" || error "User add failed"
fi

################################### Clone git repo
header "Clone git repo"
if [ -d "$GITDIR" ]; then
	#rm -r "$GITDIR"
	cd "$GITDIR"
	git pull && success "Git repository updated"  || error "Git repository update failed"
else
	git clone "$REPO" "$GITDIR"
	chmod +x "$GITDIR"/scripts/*.sh && success "Git repository cloned" || error "Git repository failed to clone"
fi

################################### Hardening
header "Hardening"
/bin/bash "$GITDIR"/scripts/hardening.sh && success "Hardening executed" || error "Hardening failed"

################################### Dynamic overclock
# Please at minimum add some heat sinks to the RPI. Better to also add a FAN. thermal throtteling is in place at 75 celcius 
# Overclocking dynamically will only affect the temp on high load for longer periods. You can mitigate that with above.
header "Overclock"
if cat /proc/cpuinfo | grep -q "Raspberry Pi 4"; then
	/bin/bash "$GITDIR"/scripts/overclock.sh && success "Overclock set, active on next reboot. Press shift during boot to disable" || error "Overclock set failed"
fi

################################### GPG
header "GPG keys"
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

################################### Storage, add auto mount & checks for usb drives
header "Storage"
if [ -f "/etc/udev/rules.d/85-usb-loader.rules" ]; then
	warning "/etc/udev/rules.d/85-usb-loader.rules exists"
else
cat >> /etc/udev/rules.d/85-usb-loader.rules <<EOF
ACTION=="add", KERNEL=="sd*[0-9]", SUBSYSTEMS=="usb", RUN+="$GITDIR/scripts/usb-initloader.sh ADD %k \$env{ID_FS_TYPE}"
ACTION=="remove", KERNEL=="sd*[0-9]", SUBSYSTEMS=="usb", RUN+="$GITDIR/scripts/usb-initloader.sh %k"
EOF
	udevadm control --reload-rules && success "Storage automation has been setup" || warning "Storage automation setup has failed"
fi

################################### UPS
#header "UPS"
#/bin/bash "$GITDIR"/scripts/ups.sh && success "UPS scripts executed" || error "UPS scripts failed"

################################### ZeroTier
#header "Zerotier/networking"
#/bin/bash "$GITDIR"/scripts/zerotier.sh && success "Zerotier setup executed" || error "Zerotier setup failed"

################################### LED / Buttons
#header "LED/buttons"
#/bin/bash "$GITDIR"/scripts/ph.sh && success "LED / button script executed" || error "LED / button script execution failed"

################################### 
if [ -f /opt/.rpi-audio-install.sh-finished ]; then
	echo "Install script finished on: $(date)" >> /opt/.rpi-audio-install.sh-finished
else
	echo "Install script finished on: $(date)" >> /opt/.rpi-audio-install.sh-finished
	reboot
fi
################################### Audio recording
header "Start recording" 
echo >> "$LOG_FILE_AUDIO" ; echo "$(date)" >> "$LOG_FILE_AUDIO"
"$GITDIR/scripts/audio.sh" >> "$LOG_FILE_AUDIO" 2>&1

#exit 0
