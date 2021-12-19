#!/bin/bash
# shellcheck disable=SC2034,SC1090,SC1091,SC2010,SC2002,SC2015,SC2181
# this script uses udev rules and
# is initiated when usb device is inserted or removed
#
# ** DEVICE INSERTED - new USB device inserted **
# ---------------------------------------------
# should be called from a udev rule like:that passes 
#   1. "ADD", 
#   2. kernel device  (%k)
#   3. filesystem type $env(ID_FS_TYPE)
#
# ACTION=="add", KERNEL=="sd*[0-9]", SUBSYSTEMS=="usb", RUN+="/home/dietpi/scripts/usb-initloader.sh ADD %k $env(ID_FS_TYPE)"
#
# Mounts usb device on /mnt/<dev>
# Logs changes to /var/log/usb-*.log
# use tail /var/log/{usb*,audio*} to look at latest events in log
#
# ** DEVICE REMOVED - USB device removed **
# ---------------------------------------------
# on remove - we only need the kernel device (%k)
# should be called from a udev rule like:
#
# ACTION=="remove", KERNEL=="sd*[0-9]", SUBSYSTEMS=="usb", RUN+="/home/dietpi/scripts/usb-initloader.sh %k"
#
# CONFIGURATION
#
# Location of the three scripts (** MUST match udev rules **)
#
################################### Variables & functions
source <(curl -sL https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/lib.sh) ; wait

################################### Check for errors + debug code and abort if something isn't right
debug_mode() {
if [ "$DEBUG" -eq 1 ]; then
    set -ex
fi
}
# 1 = ON | 0 = OFF
DEBUG=0
debug_mode

################################### Create log dir if needed
if [ -d "$LOG_DIR" ]; then
    warning "Directory $LOG_DIR exists"
else
    mkdir -p "$LOG_DIR"
    chown -R "$USER":"$USER" "$LOG_DIR"/{usb*,audio*}
    success "Directory $LOG_DIR created and permissions set" 
fi

###################################  Call load or unload script
if [ "$1" == "ADD" ]; then
    DEVICE="$2"    # USB device name (kernel passed from udev rule)
    DEVTYPE="$3"   # USB device formatting type
    DEV=$(echo "$DEVICE" | cut -c -3)
    if [ "$ROOTDRIVE" == "$DEV" ]; then
        fatal "Rootdrive: $ROOTDRIVE == udev:$DEV"
        exit 1
    fi
    echo >> "$LOG_FILE_INITLOADER"
    header "Adding USB Device $DEVICE $DATE" >> "$LOG_FILE_INITLOADER" >&2
    "$GITDIR"/scripts/usb-automount.sh "$LOG_FILE_AUTOMOUNT" "$MOUNT_DIR" "$DEVICE" "$DEVTYPE" "$AUTO_START_FINISH" >> "$LOG_FILE_INITLOADER" 2>&1&
else
    DEVICE="$1"    # USB device name (kernel passed from udev rule)
    echo >> "$LOG_FILE_INITLOADER"
    header "Unmounting USB Device $DEVICE $DATE" >> "$LOG_FILE" >&2
    "$GITDIR"/scripts/usb-unloader.sh "$LOG_FILE_UNLOADER" "$MOUNT_DIR" "$DEVICE" "$AUTO_START_FINISH" >> "$LOG_FILE_INITLOADER" 2>&1& 
fi

exit 0
