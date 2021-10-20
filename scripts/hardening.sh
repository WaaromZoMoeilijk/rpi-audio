#!/bin/bash
################################### Variables & functions
source <(curl -sL https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/lib.sh) ; wait

################################### Check for errors + debug code and abort if something isn't right
# 1 = ON | 0 = OFF
DEBUG=0
debug_mode

# fail2ban install
FB=$(dpkg-query -W -f='${Status}' fail2ban)
if [ "$FB" == "install ok installed" ]; then
        echo -e "${IYellow}Fail2ban is already installed${Color_Off}" >&2
else
        apt-get install fail2ban -y -qq

        wget -O /etc/fail2ban/jail.local https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/static/jail.local

        systemctl restart fail2ban

        if [ "$FB" == "install ok installed" ]; then
                echo ; echo -e "|" "${IGreen}Fail2ban install - Done${Color_Off} |" >&2
        else
                echo ; echo -e "|" "${IRed}Fail2ban install - Failed${Color_Off} |" >&2
        fi
fi

if [ "$UFWSTATUS" == "ERROR: Couldn't determine iptables version" ]; then
        update-alternatives --set iptables /usr/sbin/iptables-legacy && success "Fixed iptables issue with UFW. Next reboot will set firewall rules" || error "Failed to fix iptables issue with UFW"
elif [ "$UFWSTATUS" == "ERROR: problem running iptables: iptables v1.8.7 (legacy): can't initialize iptables table `filter': Table does not exist (do you need to insmod?)
Perhaps iptables or your kernel needs to be upgraded." ]; then
        warning "We need a reboot in order to use UFW with iptables"
else
echo "y" | ufw reset
ufw default allow outgoing
ufw default deny incoming
ufw limit 22/tcp
echo "y" | ufw enable
fi

exit 0
