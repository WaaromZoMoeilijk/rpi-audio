#!/bin/bash
################################### Variables & functions
source <(curl -sL https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/lib.sh) ; wait

################################### Check for errors + debug code and abort if something isn't right
# 1 = ON | 0 = OFF
DEBUG=0
debug_mode

# fail2ban install
FB=$(dpkg-query -W -f='${Status}' fail2ban)
if [ "$FB" == "ok installed" ; then
	echo -e "${IYellow}Fail2ban is already installed${Color_Off}" >&2
else
	apt install fail2ban -y

	# Fail2ban jails
	wget -O /etc/fail2ban/jail.local https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/static/jail.local

	systemctl restart fail2ban

	apt list fail2ban > /tmp/.f2b 2>&1 || true
	if ! dpkg-query -W -f='${Status}' fail2ban | grep -q "ok installed"; then
		echo ; echo -e "|" "${IGreen}Fail2ban install - Done${Color_Off} |" >&2
	else
		echo ; echo -e "|" "${IRed}Fail2ban install - Failed${Color_Off} |" >&2
	fi
fi

# UFW
echo "y" | ufw reset
ufw default allow outgoing
ufw default deny incoming
ufw limit 22/tcp
echo "y" | ufw enable

exit 0
