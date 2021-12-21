# rpi-audio
### Turnkey headless Raspberry Pi audio recorder with networking and UPS extensions 
#### Recording flow current: (powerup/usb insert) && audio-out | opusenc | gpg1 | vdmfec | tee + par2 ; wait for SIGINT && backup to local && umount  
#### Recording flow planned: (powerup/usb insert) && audio-out | opusenc | gpg1 | vdmfec | split > /mnt/sd*/Recordings/ "$LOCALSTORAGE"/ + par2 ; wait for UPS unplug && wait for loop signal && exec install.sh

#### Flash base image to SDCard
- [Download](https://www.balena.io/etcher/) and install Balena Etcher.
- Download client RaspberryPI4 (ARMv6) | [Download client RaspberryPI4 (ARMv8) (64Bit)](https://nextcloud.waaromzomoeilijk.nl/s/rkWaBseReC3pxNf)
- Flash the image to an SD Card.

#### Default login
- Username: `dietpi`
- Drowssap: `raspberry`

#### Workflow - Dev RPI DietPi
- Boot the RaspberryPI with Microphone inserted via USB. (not required for first install)
- Image contains /boot/[dietpi.txt](https://github.com/WaaromZoMoeilijk/rpi-audio/blob/main/dietpi.txt) which will handle the first setup and pull & execute [install.sh](https://github.com/WaaromZoMoeilijk/rpi-audio/blob/main/install.sh) 
- install.sh will install and set all requirements and config. It will run on every boot from now on, checking for updates and wether settings have already been applied, if yes skip or update. No WAN access will skip the update and still perform the rest of the checks.
- Let the installation run and reboot after install.
- Once the device is rebooted and up, insert USB storage (formatted to FAT32/EXT{2,3,4} and only 1 partition) and the recording will begin shortly.
- You can now leave the USB storage connected during reboots and it will auto start recording on boot.
- Also unplugging and repluggin the USB storage will initiate recording (New devices and already adopted storage both)
- Stop the recording from cli: `pkill -2 'arecord'`

#### Storage requirements
- Preformat storage device with a single partition either FAT32/EXT{2,3,4} 
- A folder "Recordings" will be created on the root folder of the storage.
- Once the storage is adopted it will also create "Recordings/.active" with device ID and timestamp and mountpoint appended.
- If "recordings/.active" is present on insert, reuse this device.
- If partition numbers is less then or more then 1 the script will exit
- Freespace check is at least 2000MB and 5% of the total storage. Same goes for local storage (backup)

#### Failsafe checks
-

#### Log files
- /var/tmp/dietpi/logs/{dietpi-automation_custom_script.log,dietpi-firstboot.log,dietpi-firstrun-setup.log,dietpi-update.log,fs_partition_resize.log}
- /var/log/{usb*,audio*}

#### Dirs
- /opt/rpi-audio
