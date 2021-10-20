#!/bin/bash
##################################### Links
# https://projects-raspberry.com/recording-sound-on-the-raspberry-pi
# https://scribles.net/voice-recording-on-raspberry-pi

##################################### Variables & functions
source <(curl -sL https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/lib.sh) ; wait

##################################### Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

##################################### Check if script runs as root
root_check

##################################### Stop all recordings just to be sure
if pgrep 'arecord'; then
	pkill -2 'arecord' && success "SIGINT send for arecord" || fatal "Failed to SIGINT arecord"
	#ps -cx -o pid,command | awk '$2 == "arecord" { print $1 }' | xargs kill -INT ; wait
	sleep 2
fi

if [ -f /tmp/.recording.lock ]; then
	rm /tmp/.recording.lock
fi

##################################### In progress flag
echo $(date) > /tmp/.recording.lock

##################################### Check USB drives	
mountvar() {
header "Checking for USB drives." 
if [[ $(find /mnt -iname '.active' | sed 's|/.active||g') ]]; then
	MNTPT=$(find /mnt -iname '.active' | sed 's|/.active||g')
	success "Active drive has been found, proceeding"
else
	fatal "No active drive has been found, please reinsert or format USB"
fi
}

# check for double drives.
# checks lines count and invokes needed script or exit.
# if 0 lines - exit
# if 1 lines - continue
# if any other number of lines - exit
case $usb_count in  
    0) fatal "No active drive has been found, please reinsert or format USB"
    ;;  
    1) mountvar
    ;;  
    *) fatal "More then 1 USB storage device found, this is not supported yet"
    ;;  
esac

##################################### Check if storage is writable
header "Checking if the storage is writable." 
touch "$MNTPT"/.test
if [ -f "$MNTPT/.test" ]; then
	success "Storage is writable"
	rm "$MNTPT"/.test
else
	error "Storage is not writable, exiting."
	exit 1
fi

##################################### Check free space
header "Checking free space available on root." 
if [ "$LOCALSTORAGEUSED" -le "$MINMB" ]; then
	error "Less then $MINMB MB available on the local storage directory: $LOCALSTORAGEUSED MB (Not USB)"
else
	success "More then $MINMB MB available on the local storage directory: $LOCALSTORAGEUSED MB (Not USB)"
fi      

header "Checking free space available on storage." 
if [ $USEP -ge "$MAXPCT" ]; then
	error "Drive has less then 10% storage capacity available, please free up space."
else
	success "Drive has more then 10% capacity available, proceeding"
fi

if [ $(df -Ph -BM $MNTPT | tail -1 | awk '{print $4}' | sed 's|M||g') -le "$MINMB" ]; then
	fatal "Less then $MINMB MB available on usb storage directory: $USEM MB (USB)"
else
	success "More then then $MINMB MB available on usb storage directory: $USEMMB (USB)"
fi

##################################### Check for USB Mic
micvar() {
header "Checking for USB Mics. Please have only 1 USB Mic/soundcard connected" 
arecord -q --list-devices | grep -m 1 -q 'USB Microphone\|USB\|usb\|Usb\|Microphone\|MICROPHONE\|microphone\|mic\|Mic\|MIC' 
if [ $? -eq 0 ]; then
	success "USB Microphone detected"
else
	fatal "No USB Microphone detected! Please plug one in now, and restart or replug USB"
	#LED/beep that mic is not detected
	# sleep 10 && reboot
fi
}

# check for amount of MICs
# checks lines count and invokes needed script or exit.
# if 0 lines - exit
# if 1 lines - continue
# if any other number of lines - exit
case $mic_count in  
    0) fatal "No USB Microphone detected! Please plug one in now, and restart or replug USB"
    ;;  
    1) micvar
    ;;  
    *) fatal "More then 1 USB Mic found"
    ;;  
esac

##################################### Set volume and unmute
header "Set volume and unmute" 
amixer -q -c $CARD set Mic 80% unmute
if [ $? -eq 0 ]; then
	success "Mic input volume set to 80% and is unmuted"
else
	fatal "Failed to set input volume"
fi

##################################### Test recording
header "Test recording"
arecord -q -f S16_LE -d 3 -r 48000 --device="hw:$CARD,0" /tmp/test-mic.wav 
if [ $? -eq 0 ]; then
	success "Test recording is done"
else
	fatal "Test recording failed"
fi

##################################### Check recording file size
header "Check if recording file size is not 0" 
if [ -s /tmp/test-mic.wav ]; then
	success "File contains data"
else
	error "File is empty! Unable to record."
fi

##################################### Test playback
header "Testing playback of the recording"
aplay /tmp/test-mic.wav
if [ $? -eq 0 ]; then
	success "Playback is ok"
	rm -r /tmp/test-mic.wav
else
	error "Playback failed"
	rm -r /tmp/test-mic.wav
fi

##################################### Check for double channel
# channel=$()
# if channel = 2 then
#else
#fi

##################################### Recording flow: audio-out | opusenc | gpg1 | vdmfec | split/tee
FILEDATE=$(date '+%Y-%m-%d_%H%M')
mkdir -p "$MNTPT/$(date '+%Y-%m-%d')" && success "Created $MNTPT/$(date '+%Y-%m-%d')" || error "Failed to create $MNTPT/$(date '+%Y-%m-%d')"
arecord -q -f S16_LE -d 0 -r 48000 --device="hw:$CARD,0" | \
opusenc --vbr --bitrate 128 --comp 10 --expect-loss 8 --framesize 60 --title "$TITLE" --artist "$ARTIST" --date $(date +%Y-%M-%d) --album "$ALBUM" --genre "$GENRE" - - | \
gpg1 	--homedir /root/.gnupg --encrypt --recipient "${GPG_RECIPIENT}" --sign --verbose --armour --force-mdc --compress-level 0 --compress-algo none \
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

###################################### Create par2 files
# Implement a last modified file check for the latest recording only
par2 create "$MNTPT/$(date '+%Y-%m-%d')/$FILEDATE.wav.gpg.par2" "$MNTPT/$(date '+%Y-%m-%d')/$FILEDATE.wav.gpg" && success "Par2 file created" || error "Failed to create Par2 file"

###################################### Verify par2 files
if [[ $(par2 verify "$MNTPT/$(date '+%Y-%m-%d')/$FILEDATE.wav.gpg.par2" | grep "All files are correct, repair is not required") ]]; then
	success "Par2 verified"
else
	error "Par2 verification failed"
fi

##################################### Check free space after recording
header "Checking free space available on storage after recording." 
if [ $USEP -ge "$MAXPCT" ]; then
	error "Drive has less then 10% storage capacity available, please free up space."
else
	success "Drive has more then 10% capacity available, proceeding"
fi

if [ $(df -Ph -BM $MNTPT | tail -1 | awk '{print $4}' | sed 's|M||g') -le "$MINMB" ]; then
	error "Less then $MINMB MB available on usb storage directory: $USEM MB (USB)"
else
	success "More then then $MINMB MB available on usb storage directory: $USEMMB (USB)"
fi

##################################### Backup recordings
if [ -d "$LOCALSTORAGE" ]; then
	chown -R "$USER":"$USER" "$LOCALSTORAGE"
else
	mkdir "$LOCALSTORAGE"
	chown -R "$USER":"$USER" "$LOCALSTORAGE"
fi

if [ "$LOCALSTORAGEUSED" -le "$MINMB" ]; then
        error "Less then $MINMB MB available on the local storage directory: $LOCALSTORAGEUSED MB (Not USB)"
else
        success "More then $MINMB MB available on the local storage directory: $LOCALSTORAGEUSED MB (Not USB)"
        rsync -aAXHv "$MNTPT"/ "$LOCALSTORAGE"/
fi      

##################################### Unmount device
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
		rmdir "$MNTPTR" && success "$MNTPTR folder removed" || error "$MNTPTR folder remove failed"
	fi
else
	success "Device not present in /etc/mtab"
fi

##################################### In progress flag
rm /tmp/.recording.lock

##################################### Finished

exit 0
