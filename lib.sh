#!/bin/bash
################################### Folders
CONFIG="/boot/config.txt"
GITDIR="/opt/rpi-audio"
HOME="/home/admin"
LOCALSTORAGE="/Recordings"
################################### System
USER="dietpi"
USERNAME="admin"
#PASSWORD=$(whiptail --passwordbox "Please enter the password for the new user $USERNAME" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
ROOTDRIVE=$(ls -la /dev/disk/by-partuuid/ | grep "$(cat /etc/fstab | grep ' / ' | awk '{print $1}' | sed 's|PARTUUID=||g')" | awk '{print $11}' | sed "s|../../||g" | sed 's/[0-9]*//g')
DEV=$(lshw -short -c disk | grep -v "$ROOTDRIVE" | awk '{print $2}' | sed 's|path||g' | sed -e '/^$/d')
CHECKDRIVESIZE=$(lshw -short -c disk | grep -v "$ROOTDRIVE" | tail -n+3 | awk '{print $2,$4}')
DEVID=$(ls -la /dev/disk/by-id/ | grep "$DEV" | grep -v 'part' | awk '{print $9}' | sed 's|:0||g')
BLOCKSIZE=$(blockdev --getbsz "$DEV")
USEP=$(df -h | grep "$DEV" | awk '{ print $5 }' | cut -d'%' -f1)
LOCALSTORAGEUSEDM=$(df -Ph -BM "$LOCALSTORAGE" | tail -1 | awk '{print $4}' | sed 's|M||g')
################################### Opusenc
TITLE=$(cat /etc/hostname)
ARTIST="RaspberryPI"
ALBUM="N/a"
GENRE="Recording"
################################### GPG
GPG_RECIPIENT="recorder@waaromzomoeilijk.nl"
################################### Network
WANIP4=$(curl -s -k -m 5 https://ipv4bot.whatismyipaddress.com)
GATEWAY=$(ip route | grep default | awk '{print $3}')
IFACE=$(ip r | grep "default via" | awk '{print $5}')
ADDRESS=$(hostname -I | cut -d ' ' -f 1)
################################### Links
ISSUES="https://github.com/WaaromZoMoeilijk/rpi-audio/issues"
REPO="https://github.com/WaaromZoMoeilijk/rpi-audio" 
################################### Misc
REBOOT="sleep 40 && reboot"
DATE=$(date '+%Y-%m-%d - %H:%M:%S')
NAMEDATE=$(date '+%Y-%m-%d_%H:%M:%S')
################################### Storage
SCRIPT_DIR="$GITDIR/scripts"
LOG_DIR="/var/log"
LOG_FILE="$LOG_DIR/usb-automount.log"
MOUNT_DIR=/mnt # Mount folder (sda1 will be added underneath this)
# Optional parameter to:
#   - auto start a program on ADD
#   - auto end program on REMOVE
AUTO_START_FINISH=1 # Set to 0 if false; 1 if true
################################### Audio
CARD=$(arecord -l | grep -m 1 'USB Microphone\|USB\|usb\|Usb\|Microphone\|MICROPHONE\|microphone\|mic\|Mic\|MIC' | awk '{print $2}' | sed 's|:||g')
################################### Functions
is_root() {
    if [[ "$EUID" -ne 0 ]]
    then
        return 1
    else
        return 0
    fi
}
###################################
root_check() {
if ! is_root
then
    msg_box "Failed, script needs sudo permission"
    exit 1
fi
}
###################################
debug_mode() {
if [ "$DEBUG" -eq 1 ]
then
    set -ex
fi
}
###################################
is_mounted() {
    grep -q "$1" /etc/mtab
}
###################################
fatal() {
    echo "Error: $*"
    exit 1
}
###################################
apt_install() {
    apt install -y
}
###################################
apt_update() {
    apt update
}
###################################
apt_upgrade() {
    sudo -E apt -o "Dpkg::Options::=--force-confdef" -o "Dpkg::Options::=--force-confold" full-upgrade -y 
}
###################################
apt_autoremove() {
    apt autoremove -y
}
###################################
apt_autoclean() {
    apt -y autoclean
    #-qq -d
}
################################### Spinner during long commands
spinner() {
    printf '['
    while ps "$!" > /dev/null; do
        echo -n '⣾⣽⣻'
        sleep '.7'
    done
    echo ']'
}
################################### Whiptail auto-size
calc_wt_size() {
    WT_HEIGHT=17
    WT_WIDTH=$(tput cols)

    if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
        WT_WIDTH=80
    fi
    if [ "$WT_WIDTH" -gt 178 ]; then
        WT_WIDTH=120
    fi
    WT_MENU_HEIGHT=$((WT_HEIGHT-7))
    export WT_MENU_HEIGHT
}
###################################
msg_box() {
    [ -n "$2" ] && local SUBTITLE=" - $2"
    whiptail --title "$TITLE$SUBTITLE" --msgbox "$1" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3
}
###################################
yesno_box_yes() {
    [ -n "$2" ] && local SUBTITLE=" - $2"
    if (whiptail --title "$TITLE$SUBTITLE" --yesno "$1" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    then
        return 0
    else
        return 1
    fi
}
###################################
yesno_box_no() {
    [ -n "$2" ] && local SUBTITLE=" - $2"
    if (whiptail --title "$TITLE$SUBTITLE" --defaultno --yesno "$1" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    then
        return 0
    else
        return 1
    fi
}
###################################
input_box() {
    [ -n "$2" ] && local SUBTITLE=" - $2"
    local RESULT && RESULT=$(whiptail --title "$TITLE$SUBTITLE" --nocancel --inputbox "$1" "$WT_HEIGHT" "$WT_WIDTH" 3>&1 1>&2 2>&3)
    echo "$RESULT"
}
###################################
input_box_flow() {
    local RESULT
    while :
    do
        RESULT=$(input_box "$1" "$2")
        if [ -z "$RESULT" ]
        then
            msg_box "Input is empty, please try again." "$2"
        elif ! yesno_box_yes "Is this correct? $RESULT" "$2"
        then
            msg_box "OK, please try again." "$2"
        else
            break
        fi
    done
    echo "$RESULT"
}
###################################
install_if_not() {
if ! dpkg-query -W -f='${Status}' "${1}" | grep -q "ok installed"
then
    apt update -q4 & spinner_loading && RUNLEVEL=1 apt install "${1}" -y
fi
}
###################################
print_text_in_color() {
printf "%b%s%b\n" "$1" "$2" "$Color_Off"
}
# Reset
Color_Off='\e[0m'       # Text Reset
# Regular Colors
Black='\e[0;30m'        # Black
Red='\e[0;31m'          # Red
Green='\e[0;32m'        # Green
Yellow='\e[0;33m'       # Yellow
Blue='\e[0;34m'         # Blue
Purple='\e[0;35m'       # Purple
Cyan='\e[0;36m'         # Cyan
White='\e[0;37m'        # White
# Bold
BBlack='\e[1;30m'       # Black
BRed='\e[1;31m'         # Red
BGreen='\e[1;32m'       # Green
BYellow='\e[1;33m'      # Yellow
BBlue='\e[1;34m'        # Blue
BPurple='\e[1;35m'      # Purple
BCyan='\e[1;36m'        # Cyan
BWhite='\e[1;37m'       # White
# Underline
UBlack='\e[4;30m'       # Black
URed='\e[4;31m'         # Red
UGreen='\e[4;32m'       # Green
UYellow='\e[4;33m'      # Yellow
UBlue='\e[4;34m'        # Blue
UPurple='\e[4;35m'      # Purple
UCyan='\e[4;36m'        # Cyan
UWhite='\e[4;37m'       # White
# Background
On_Black='\e[40m'       # Black
On_Red='\e[41m'         # Red
On_Green='\e[42m'       # Green
On_Yellow='\e[43m'      # Yellow
On_Blue='\e[44m'        # Blue
On_Purple='\e[45m'      # Purple
On_Cyan='\e[46m'        # Cyan
On_White='\e[47m'       # White
# High Intensity
IBlack='\e[0;90m'       # Black
IRed='\e[0;91m'         # Red
IGreen='\e[0;92m'       # Green
IYellow='\e[0;93m'      # Yellow
IBlue='\e[0;94m'        # Blue
IPurple='\e[0;95m'      # Purple
ICyan='\e[0;96m'        # Cyan
IWhite='\e[0;97m'       # White
# Bold High Intensity
BIBlack='\e[1;90m'      # Black
BIRed='\e[1;91m'        # Red
BIGreen='\e[1;92m'      # Green
BIYellow='\e[1;93m'     # Yellow
BIBlue='\e[1;94m'       # Blue
BIPurple='\e[1;95m'     # Purple
BICyan='\e[1;96m'       # Cyan
BIWhite='\e[1;97m'      # White
# High Intensity backgrounds
On_IBlack='\e[0;100m'   # Black
On_IRed='\e[0;101m'     # Red
On_IGreen='\e[0;102m'   # Green
On_IYellow='\e[0;103m'  # Yellow
On_IBlue='\e[0;104m'    # Blue
On_IPurple='\e[0;105m'  # Purple
On_ICyan='\e[0;106m'    # Cyan
On_IWhite='\e[0;107m'   # White
