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

##################################### Check USB drives
# Handeled by automount scripts, just here for reference.
#jq -n --arg RD $ROOTDRIVE '{"RootDrive":"\($RD)"}'
#jq -n --arg UUID $(cat /etc/fstab | grep ' / ' | awk '{print $1}' | sed 's|PARTUUID=||g') '{"RootDrivePartitionID":"\($UUID)"}'

#for DRIVE in "$CHECKDRIVE"; do
#DRIVEC=$(echo "$DRIVE" | sed 's|/dev/||g' )
#ls -la /dev/disk/by-id/ | grep "$DRIVEC" | grep -v 'part' | awk '{print $9}' | sed 's|:0||g' > /tmp/.drive
#lshw -short -c disk | grep "$DRIVE" | tail -n+3 | awk '{print $2,$4}' | awk '{print $2}' > /tmp/.drivesize
#jq -n --args USB $(cat /tmp/.drive) USBS $(cat /tmp/.drivesize) '{"StorageDevID-$USB":"\($USB1)"}'
#sleep 1
#done

#If USB drive is true
#Set write path to USB
#else 
#Set write path to SDcard


##################################### Check if storage is writable and freespace is more than 10%
# Write test
touch $MOUNT_DIR/$DEVICE/.test
if [ -z "$(ls "$MOUNT_DIR/$DEVICE/Recordings/.active")" ]; then
	echo -e "|"  "${IGreen}Storage is writable! ${Color_Off} |" >&2
	rm $MOUNT_DIR/$DEVICE/.test
else
	echo -e "|"  "${IRed}Storage is not writable, exiting. ${Color_Off} |" >&2
	exit 1
fi

# Storage
if [ $USEP -ge 90 ]; then
	echo -e "|"  "${IRed}Drive has less then 10% storage capacity available, please free up space. ${Color_Off} |" >&2
	exit 1
else
	echo -e "|"  "${IGreen}Drive has more then 10% capacity available, proceeding!   ${Color_Off} |" >&2
fi

##################################### Recording flow: audio-out | opusenc | gpg1 | vdmfec | split/tee
arecord -q -f S16_LE -d 3 -r 48000 --device="hw:$CARD,0" | \
opusenc --vbr --bitrate 128 --comp 10 --expect-loss 8 --framesize 60 --title "$TITLE" --artist "$ARTIST"--date $(date +%Y-%M-%d) --album "$ALBUM" --genre "$GENRE" - - | \
gpg --encrypt --recipient "${GPG_RECIPIENT}" --sign --verbose --armour --force-mdc --compress-level 0 --compress-algo none \ 
    --no-emit-version --no-random-seed-file --no-secmem-warning --personal-cipher-preferences AES256 --personal-digest-preferences SHA512 \
    --personal-compress-preferences none --cipher-algo AES256 --digest-algo SHA512 > /mnt/$DRIVE/$(date +%Y-%m-%d_%H-%M-%S).wav.gpg.par2  #| \

# Not working with vdmfec
#vdmfec -v -b "$BLOCKSIZE" -n 32 -k 24 | \
#tee /mnt/$DRIVE/$(date +%Y-%m-%d_%H-%M-%S).opus.gpg.vdmfec.wav.asc 

###################################### Create and verify par2 files
par2 create /mnt/$DRIVE/$(date +%Y-%m-%d_%H)-*.wav.gpg.par2 /mnt/$DRIVE/$(date +%Y-%m-%d_%H)-*.wav.gpg
# if par2 verify /tmp/recording.opus.gpg.vdmfec.wav.asc.par2 /tmp/recording.opus.gpg.vdmfec.wav.asc

##################################### Backup recordings
#rsync -aAXHv "$USB"/ "$LOCALSTORAGE"/

##################################### Finished



exit 0
