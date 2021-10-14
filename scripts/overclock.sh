#!/bin/bash
# No core freq changes for RPI4 
# https://www.raspberrypi.org/documentation/configuration/config-txt/overclocking.md
# https://elinux.org/RPiconfig

CONFIG="/boot/config.txt"

sed -i '/arm_freq=/d' "$CONFIG"
sed -i '/arm_freq_min=/d' "$CONFIG"
sed -i '/over_voltage=/d' "$CONFIG"
sed -i '/over_voltage_min=/d' "$CONFIG"
sed -i '/temp_limit=/d' "$CONFIG"
sed -i '/initial_turbo=/d' "$CONFIG"
sed -i '/core_freq/d' "$CONFIG"
sed -i '/sdram_freq/d' "$CONFIG"
sed -i '/-------Overclock-------/d' "$CONFIG"

# Dynamic overclock config
cat >> "$CONFIG" <<EOF
#-------Overclock-------
arm_freq=2000
arm_freq_min=600
over_voltage=6
over_voltage_min=0
temp_limit=75
initial_turbo=60
EOF

exit 0
