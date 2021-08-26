#!/bin/bash

# UFW
apt install ufw -y
ufw default allow outgoing
ufw default deny incoming
ufw limit 22/tcp
ufw enable

# Fail2ban
# SSH

# More to come

exit 0
