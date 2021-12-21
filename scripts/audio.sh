#!/bin/bash
# shellcheck disable=SC2034,SC1090,SC1091,SC2010,SC2002,SC2015,SC2181,SC2129,SC2012
##################################### Variables & functions
source <(curl -sL https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/lib.sh) ; wait
##################################### Check for errors + debug code and abort if something isn't right
# 1 = ON / 0 = OFF
DEBUG=0
debug_mode
sleep 2
##################################### Check if script runs as root
root_check
##################################### Stop all recordings just to be sure
stop_all_recordings
##################################### In progress flag
date > /tmp/.recording.lock
##################################### Check USB drives	
check_usb_drives
##################################### Check if storage is writable
storage_writable_check
##################################### Check free space
check_freespace_prior
##################################### Check for USB Mic
check_usb_mic
##################################### Set volume and unmute
set_vol
##################################### Test recording
test_rec
##################################### Check recording file size
check_rec_filesize
##################################### Test playback
test_playback
##################################### Check for double channel
check_double_channel
##################################### Recording flow: audio-out | opusenc | gpg1 | vdmfec | split/tee
record_audio
###################################### Create par2 files
create_par2
###################################### Verify par2 files
verify_par2
##################################### Check free space after recording
check_freespace_post
##################################### Backup recordings ///// make this split
backup_recordings
##################################### Sync logs to USB
sync_to_usb
##################################### Unmount device
#unmount_device
##################################### In progress flag
rm /tmp/.recording.lock
##################################### Finished

exit 0
