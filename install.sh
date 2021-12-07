#!/bin/bash
# Installation script for an automated audio recorder on a RaspberryPI4 running DietPI
# Please edit the variable's in lib.sh to accomodate your needs
# info@waaromzomoeilijk.nl
# login root/dietpi //// raspberry

# Version
# v0.0.9

################################### Variables & functions
if ping -c 1 google.com; then
  source <(curl -sL https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/lib.sh) ; wait
else
  source /opt/rpi-audio/lib.sh
fi

# For local deployments please # comment all the lines in the above section
# And uncomment the below section (run the scritps inside the rpi-audio folder)
# source $pwd/lib.sh

###################################  Check for errors + debug code and abort if something isn't right
# 1 = ON / 0 = OFF
DEBUG=1
debug_mode
################################### Check if script runs as root
root_check
clear
################################### Touch log files
touch_log
################################### Prefer IPv4 for apt
ipv4_apt
################################### Upstart
rc_local
################################### Set timezone based upon WAN ip
tz_wan_ip
################################### Update OS
update_os
################################### Dependencies installation
dependencies_install
################################### VDMFEC installation
vdmfec_install
################################### Allow access, temp during dev
dev_access
################################### Create PAM user
create_user
################################### Clone/Pull(update) git repo
git_clone_pull
################################### Hardening RPI4
harden_system
################################### Dynamic overclock RPI4
overclock_pi
################################### GPG setup
gpg_keys
################################### Storage, add auto mount & checks for usb drives
setup_usb
################################### UPS
#ups_setup
################################### ZeroTier
#zerotier_setup
################################### LED / Buttons
#button_setup
################################### Finished installation flag
finished_installation_flag
################################### Audio start recording
start_recording

#exit 0
