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
if [ $? -eq 0 ]
then
	echo
        echo -e "|"  "${IGreen}USB Microphone detected! ${Color_Off} |"
else
        echo -e "|"  "${IRed}No USB Microphone detected! Please plug one in now, and restart! ${Color_Off} |" >&2
        #LED/beep that mic is not detected
        exit 1
fi
sleep 4

##################################### Set volume and unmute
echo ; echo "Set volume and unmute" ; echo 
amixer -q -c $CARD set Mic 100% unmute
if [ $? -eq 0 ]
then
	echo -e "|"  "${IGreen}Mic input volume set to 100% and is unmuted${Color_Off} |"
else
        echo -e "|"  "${IRed}Failed to set input volume${Color_Off} |" >&2
        #exit 1
fi
sleep 4

##################################### Test recording
echo ; echo "Test recording" ; echo
arecord -q -f S16_LE -d 3 -r 48000 --device="hw:$CARD,0" /tmp/test-mic.wav 
if [ $? -eq 0 ]
then
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
if [ $? -eq 0 ]
then
	echo
        echo -e "|"  "${IGreen}Playback is ok! ${Color_Off} |"
	rm -r /tmp/test-mic.wav
else
	echo
        echo -e "|"  "${IRed}Playback failed! ${Color_Off} |" >&2
	rm -r /tmp/test-mic.wav
        #exit 1
fi
sleep 4

##################################### Finished
exit 0
