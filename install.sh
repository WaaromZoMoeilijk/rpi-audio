#!/bin/bash
# Installation script for an automated audio recorder on a RaspberryPI4 running DietPI
# info@waaromzomoeilijk.nl
# login root/dietpi

# Version
# v0.0.9

################################### Variables & functions
source <(curl -sL https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/lib.sh) ; wait

###################################  Check for errors + debug code and abort if something isn't right
# 1 = ON / 0 = OFF
DEBUG=0
debug_mode
###################################  Check if script runs as root
root_check
clear
################################### Prefer IPv4 for apt
ipv4_apt
################################### Upstart
rc_local
################################### Set timezone based upon WAN ip
tz_wan_ip
#################################### Update OS
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
