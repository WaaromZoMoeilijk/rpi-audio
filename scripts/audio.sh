#!/bin/bash
##################################### Links
# https://projects-raspberry.com/recording-sound-on-the-raspberry-pi
# https://scribles.net/voice-recording-on-raspberry-pi

##################################### Variables & functions
source <(curl -sL https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/lib.sh)

##################################### Check for errors + debug code and abort if something isn't right
# 1 = ON
# 0 = OFF
DEBUG=0
debug_mode

##################################### Check if script runs as root
root_check

##################################### Stop all recordings just to be sure
if [ -f /tmp/.recording.lock ]; then
	ps -cx -o pid,command | awk '$2 == "arecord" { print $1 }' | xargs kill -INT
	rm /tmp/.recording.lock
fi

##################################### In progress flag
echo "$DATE" > /tmp/.recording.lock

##################################### Check USB drives	
# Implement a check for double drives.
echo ; echo -e "|" "${IBlue}Checking for USB drives.${Color_Off} |" >&2 ; echo 
if [[ $(find /mnt -iname '.active' | sed 's|/.active||g') ]]; then
        MNTPT=$(find /mnt -iname '.active' | sed 's|/.active||g')
        echo -e "|"  "${IGreen}Active drive has been found, proceeding!   ${Color_Off} |" >&2
else
        echo -e "|"  "${IRed}No active drive has been found, please reinsert or format USB. ${Color_Off} |" >&2
        exit 1
fi

##################################### Check if storage is writable
echo ; echo -e "|" "${IBlue}Checking if the storage is writable.${Color_Off} |" >&2 ; echo 
touch "$MNTPT"/.test
if [ -z "$(ls "$MNTPT/.test")" ]; then
	echo -e "|"  "${IGreen}Storage is writable! ${Color_Off} |" >&2
	rm "$MNTPT"/.test
else
	echo -e "|"  "${IRed}Storage is not writable, exiting. ${Color_Off} |" >&2
	exit 1
fi

##################################### Check free space
echo ; echo -e "|" "${IBlue}Checking free space available on storage.${Color_Off} |" >&2 ; echo 
if [ $USEP -ge 90 ]; then
	echo -e "|"  "${IRed}Drive has less then 10% storage capacity available, please free up space. ${Color_Off} |" >&2
else
	echo -e "|"  "${IGreen}Drive has more then 10% capacity available, proceeding! ${Color_Off} |" >&2
fi

USEDM=$(df -Ph -BM "$MNTPT" | tail -1 | awk '{print $4}' | sed 's|M||g')
if [ "$USEM " -le 500 ]; then
	echo ; echo -e "|"  "${IRed}Less then 500MB available on usb storage directory: $USEM MB (USB)${Color_Off} |" >&2
	exit 1
else
	echo ; echo -e "|"  "${IGreen}More then then 500MB available on usb storage directory: $USEMMB (USB)${Color_Off} |" >&2
fi	

##################################### Check for USB Mic
echo ; echo -e "|" "${IBlue}Checking for USB Mics. Please have only 1 USB Mic/soundcard connected!${Color_Off} |" >&2 ; echo 
arecord -q --list-devices | grep -m 1 -q 'USB Microphone\|USB\|usb\|Usb\|Microphone\|MICROPHONE\|microphone\|mic\|Mic\|MIC' 
if [ $? -eq 0 ]; then
	    echo ; echo -e "|"  "${IGreen}USB Microphone detected! ${Color_Off} |"
else
        echo -e "|"  "${IRed}No USB Microphone detected! Please plug one in now, and restart! ${Color_Off} |" >&2
        #LED/beep that mic is not detected
	    # sleep 10 && reboot
        exit 1
fi

##################################### Set volume and unmute
echo ; echo -e "|" "${IBlue}Set volume and unmute${Color_Off} |" >&2 ; echo 
amixer -q -c $CARD set Mic 80% unmute
if [ $? -eq 0 ]; then
	echo -e "|"  "${IGreen}Mic input volume set to 80% and is unmuted${Color_Off} |"
else
        echo -e "|"  "${IRed}Failed to set input volume${Color_Off} |" >&2
        #exit 1
fi

##################################### Test recording
echo ; echo -e "|" "${IBlue}Test recording${Color_Off} |" >&2 ; echo
arecord -q -f S16_LE -d 3 -r 48000 --device="hw:$CARD,0" /tmp/test-mic.wav 
if [ $? -eq 0 ]; then
        echo -e "|"  "${IGreen}Test recording is done! ${Color_Off} |"
else
        echo -e "|"  "${IRed}Test recording failed! ${Color_Off} |" >&2
        #exit 1
fi

##################################### Check recording file size
echo ; echo -e "|" "${IBlue}Check if recording file size is not 0${Color_Off} |" >&2 ; echo 
if [ -s /tmp/test-mic.wav ]; then
        echo -e "|"  "${IGreen}File contains data! ${Color_Off} |"
else
        echo -e "|"  "${IRed}File is empty! Unable to record. ${Color_Off} |" >&2
	#exit 1
fi

##################################### Test playback
echo ; echo -e "|" "${IBlue}Testing playback of the recording${Color_Off} |" >&2 ; echo
aplay /tmp/test-mic.wav
if [ $? -eq 0 ]; then
	echo ; echo -e "|"  "${IGreen}Playback is ok! ${Color_Off} |"
	rm -r /tmp/test-mic.wav
else
	echo ; echo -e "|"  "${IRed}Playback failed! ${Color_Off} |" >&2
	rm -r /tmp/test-mic.wav
        #exit 1
fi

##################################### Check for double channel
# channel=$()
# if channel = 2 then
#else
#fi

##################################### Recording flow: audio-out | opusenc | gpg1 | vdmfec | split/tee
arecord -q -f S16_LE -d 0 -r 48000 --device="hw:$CARD,0" | \
opusenc --vbr --bitrate 128 --comp 10 --expect-loss 8 --framesize 60 --title "$TITLE" --artist "$ARTIST" --date $(date +%Y-%M-%d) --album "$ALBUM" --genre "$GENRE" - - | \
gpgv1 	--encrypt --recipient "${GPG_RECIPIENT}" --sign --verbose --armour --force-mdc --compress-level 0 --compress-algo none \
	--no-emit-version --no-random-seed-file --no-secmem-warning --personal-cipher-preferences AES256 --personal-digest-preferences SHA512 \
	--personal-compress-preferences none --cipher-algo AES256 --digest-algo SHA512 | \
vdmfec -v -b "$BLOCKSIZE" -n 32 -k 24 | \
tee "$MNTPT/$(date +%Y-%m-%d_%H:%M:%S).wav.gpg"

# Reverse Pipe
#vdmfec -d -v -b "$BLOCKSIZE" -n 32 -k 24 /root/recording.wav.gpg | \
#gpgv1 --decrypt > /root/recording.wav 

# SIGINT arecord - control + c equivilant. Used to end the arecord cmd and continue the pipe. Triggered when UPS mains is unplugged.
#ps -cx -o pid,command | awk '$2 == "arecord" { print $1 }' | xargs kill -INT

###################################### Create par2 files
# Implement a last modified file check for the latest recording only
par2 create "$MNTPT/$(date +%Y-%m-%d_%H:%M:%S).wav.gpg.par2" "$MNTPT/$(date +%Y-%m-%d_%H)-*.wav.gpg"

###################################### Verify par2 files
if [[ $(par2 verify "$MNTPT/$(date +%Y-%m-%d_%H)*.wav.gpg.par2" | grep "All files are correct, repair is not required") ]]; then
	echo ; echo -e "|"  "${IGreen}Par2 verified! ${Color_Off} |"
else
	echo ; echo -e "|"  "${IRed}Par2 verification failed! ${Color_Off} |" >&2
        #exit 1
fi

##################################### Backup recordings
if [ -d "$LOCALSTORAGE" ]; then
	chown -R "$USER":"$USER" "$LOCALSTORAGE"
else
	mkdir "$LOCALSTORAGE"
	chown -R "$USER":"$USER" "$LOCALSTORAGE"
fi

if [ "$LOCALSTORAGEUSED" -le 500 ]; then
	echo ; echo -e "|"  "${IRed}Less then 500MB available on the local storage directory: $LOCALSTORAGEUSED MB (Not USB)${Color_Off} |" >&2
else
	echo ; echo -e "|"  "${IGreen}More then then 500MB available on the local storage directory: $LOCALSTORAGEUSED MB (Not USB)${Color_Off} |" >&2
	rsync -aAXHv "$MNTPT"/ "$LOCALSTORAGE"/
fi	

##################################### In progress flag
rm /tmp/.recording.lock

##################################### Finished

exit 0
