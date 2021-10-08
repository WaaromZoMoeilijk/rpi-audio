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

##################################### Check USB drives		
if [[ $(find /mnt -iname '.active' | sed 's|/.active||g') ]]; then
        MNTPT=$(find /mnt -iname '.active' | sed 's|/.active||g')
        echo -e "|"  "${IGreen}Active drive has been found, proceeding!   ${Color_Off} |" >&2
else
        echo -e "|"  "${IRed}No active drive has been found, please reinsert or format USB. ${Color_Off} |" >&2
        exit 1
fi

##################################### Check if storage is writable
clear ; echo "Checking if the storage is writable." ; echo 
touch "$MNTPT"/.test
if [ -z "$(ls "$MNTPT/.test")" ]; then
	echo -e "|"  "${IGreen}Storage is writable! ${Color_Off} |" >&2
	rm "$MNTPT"/.test
else
	echo -e "|"  "${IRed}Storage is not writable, exiting. ${Color_Off} |" >&2
	exit 1
fi
sleep 4

##################################### Check free space
clear ; echo "Checking free space available on storage." ; echo 
if [ $USEP -ge 90 ]; then
	echo -e "|"  "${IRed}Drive has less then 10% storage capacity available, please free up space. ${Color_Off} |" >&2
	exit 1
else
	echo -e "|"  "${IGreen}Drive has more then 10% capacity available, proceeding! ${Color_Off} |" >&2
fi
sleep 4

##################################### Check for USB Mic
clear ; echo "Checking for USB Mics. Please have only 1 USB Mic/soundcard connected!" ; echo 
arecord -q --list-devices | grep -m 1 -q 'USB Microphone\|USB\|usb\|Usb\|Microphone\|MICROPHONE\|microphone\|mic\|Mic\|MIC' 
if [ $? -eq 0 ]; then
	echo ; echo -e "|"  "${IGreen}USB Microphone detected! ${Color_Off} |"
else
        echo -e "|"  "${IRed}No USB Microphone detected! Please plug one in now, and restart! ${Color_Off} |" >&2
        #LED/beep that mic is not detected
	# sleep 10 && reboot
        exit 1
fi
sleep 4

##################################### Set volume and unmute
echo ; echo "Set volume and unmute" ; echo 
amixer -q -c $CARD set Mic 80% unmute
if [ $? -eq 0 ]; then
	echo -e "|"  "${IGreen}Mic input volume set to 80% and is unmuted${Color_Off} |"
else
        echo -e "|"  "${IRed}Failed to set input volume${Color_Off} |" >&2
        #exit 1
fi
sleep 4

##################################### Test recording
echo ; echo "Test recording" ; echo
arecord -q -f S16_LE -d 3 -r 48000 --device="hw:$CARD,0" /tmp/test-mic.wav 
if [ $? -eq 0 ]; then
        echo -e "|"  "${IGreen}Test recording is done! ${Color_Off} |"
else
        echo -e "|"  "${IRed}Test recording failed! ${Color_Off} |" >&2
        #exit 1
fi
sleep 4

##################################### Check recording file size
echo ; echo "Check if recording file size is not 0" ; echo 
if [ -s /tmp/test-mic.wav ]; then
        echo -e "|"  "${IGreen}File contains data! ${Color_Off} |"
else
        echo -e "|"  "${IRed}File is empty! Unable to record. ${Color_Off} |" >&2
	#exit 1
fi
sleep 4

##################################### Test playback
echo ; echo "Testing playback of the recording" ; echo
aplay /tmp/test-mic.wav
if [ $? -eq 0 ]; then
	echo ; echo -e "|"  "${IGreen}Playback is ok! ${Color_Off} |"
	rm -r /tmp/test-mic.wav
else
	echo ; echo -e "|"  "${IRed}Playback failed! ${Color_Off} |" >&2
	rm -r /tmp/test-mic.wav
        #exit 1
fi
sleep 4

##################################### Recording flow: audio-out | opusenc | gpg1 | vdmfec | split/tee
arecord -q -f S16_LE -d 0 -r 48000 --device="hw:$CARD,0" | \
opusenc --vbr --bitrate 128 --comp 10 --expect-loss 8 --framesize 60 --title "$TITLE" --artist "$ARTIST" --date $(date +%Y-%M-%d) --album "$ALBUM" --genre "$GENRE" - - | \
gpg 	--encrypt --recipient "${GPG_RECIPIENT}" --sign --verbose --armour --force-mdc --compress-level 0 --compress-algo none \
	--no-emit-version --no-random-seed-file --no-secmem-warning --personal-cipher-preferences AES256 --personal-digest-preferences SHA512 \
	--personal-compress-preferences none --cipher-algo AES256 --digest-algo SHA512 | \
vdmfec -v -b "$BLOCKSIZE" -n 32 -k 24 | \
tee "$MNTPT/$(date +%Y-%m-%d_%H:%M:%S).wav.gpg"

# Reverse Pipe
#vdmfec -d -v -b "$BLOCKSIZE" -n 32 -k 24 /root/recording.wav.gpg | \
#gpg --decrypt > /root/recording.wav 

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

rsync -aAXHv "$MNTPT"/ "$LOCALSTORAGE"/

##################################### Finished

exit 0
