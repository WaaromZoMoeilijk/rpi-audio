#!/bin/bash
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
# Mounts usb device on /media/<dev>
# Logs changes to /var/log/syslog
# use tail /var/log/syslog to look at latest events in log
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
source <(curl -sL https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/lib.sh)

################################### Check for errors + debug code and abort if something isn't right
# 1 = ON | 0 = OFF
DEBUG=1
debug_mode

mkdir -p "$LOG_DIR"
touch "$LOG_FILE"
chown -R "$USER":"$USER" "$LOG_DIR"

# Call speciality script and leave this one (with trailing "&")
if [ "$1" == "ADD" ]; then
    DEVICE="$2"    # USB device name (kernel passed from udev rule)
    DEVTYPE="$3"   # USB device formatting type
    echo "==> Adding USB Device $DEVICE" >> "$LOG_FILE"
    ${SCRIPT_DIR}/usb-automount.sh "$LOG_FILE" "$MOUNT_DIR" "$DEVICE" "$DEVTYPE" "$AUTO_START_FINISH" >> "$LOG_FILE" 2>&1&
else
    DEVICE="$1"    # USB device name (kernel passed from udev rule)
    echo "==> Unmounting USB Device $DEVICE" >> "$LOG_FILE"
    ${SCRIPT_DIR}/usb-unloader.sh "$LOG_FILE" "$MOUNT_DIR" "$DEVICE" "$AUTO_START_FINISH" >> "$LOG_FILE" 2>&1&
fi
