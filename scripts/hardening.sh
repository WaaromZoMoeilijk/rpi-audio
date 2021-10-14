#!/bin/bash

# fail2ban install
dietpi-software install 73

# UFW
echo "yes" | ufw reset
ufw default allow outgoing
ufw default deny incoming
ufw limit 22/tcp
ufw allow http
ufw allow https
ufw enable

# Fail2ban
wget -O /etc/fail2ban/jail.local https://raw.githubusercontent.com/WaaromZoMoeilijk/rpi-audio/main/static/jail.local

systemctl restart fail2ban

exit 0
