# rpi-audio
### Turnkey headless Raspberry Pi audio recorder with networking and UPS extensions 
#### Recording flow current: (powerup/usb insert) && audio-out | opusenc | gpg1 | vdmfec | tee + par2 ; wait for SIGINT && backup to local && umount  
#### Recording flow planned: (powerup/usb insert) && audio-out | opusenc | gpg1 | vdmfec | tee + par2 ; wait for UPS unplug && backup to local && umount && shutdown

#### To do
- [ ] Encryption keys mechanism
- [ ] UPS [8](https://github.com/WaaromZoMoeilijk/rpi-audio/issues/8)
- [ ] LTE [7](https://github.com/WaaromZoMoeilijk/rpi-audio/issues/7) [14](https://github.com/WaaromZoMoeilijk/rpi-audio/issues/14)
- [ ] Dual channel
- [ ] Audio parameters [4](https://github.com/WaaromZoMoeilijk/rpi-audio/issues/4) [5](https://github.com/WaaromZoMoeilijk/rpi-audio/issues/5)

#### Flash base image to SSD / SDCard
- [Download](https://www.balena.io/etcher/) and install Balena Etcher.
- Download client RaspberryPI4 (8GB) (ARMv6) | [Download client RaspberryPI4 (8GB) (ARMv8) (64Bit)](https://nextcloud.waaromzomoeilijk.nl/s/rkWaBseReC3pxNf)
- Flash the image to an SD Card / SSD (recommended).

#### Enable SSD boot (most recently purchased RPI4's will already have this enabled)
- [Download](https://www.raspberrypi.org/downloads) Raspberry Pi Imager 
- Get an SD card. The contents will get overwritten!
- `Launch` Raspberry Pi Imager
- Select Misc utility images under `Operating System`
- Select `Bootloader`
- Select `boot-mode SD (primary)` then `USB (secondary)`. Obviously if you want to run your SSD, don't insert an SD card.
- Select `SD card` and then `Write`
- `Boot` the Raspberry Pi with the new image and wait for at least 10 seconds.
- The green activity LED will blink with a steady pattern and the HDMI display will be green on success.
- `Power off` the Raspberry Pi and `remove the SD card`.

#### Default login
- Username: `dietpi`
- Drowssap: `raspberry`

#### Workflow - Dev RPI DietPi
- Boot the RaspberryPI with Microphone inserted via USB. (not required for first install)
- Image contains [dietpi.txt](https://github.com/WaaromZoMoeilijk/rpi-audio/blob/main/dietpi.txt) which will handle the first setup and pull & execute [install.sh](https://github.com/WaaromZoMoeilijk/rpi-audio/blob/main/install.sh) 
- install.sh will install and set all requirements and config. It will run on every boot from now on, checking for updates and wether settings have already been applied, if yes skip or update.
- Let the installation run and reboot after install (SD card: X / SSD: less then 5 mins).
- Once the device is rebooted and up, insert USB storage (formatted to FAT32/NTFS/EXT{2,3,4} and only 1 partition) and the recording will begin shortly.
- You can now leave the USB storage connected during reboots and it will auto start recording on boot.
- Also unplugging and repluggin the USB storage will initiate recording (New devices and already adopted storage both)
- Stop the recording from cli: `pkill -2 'arecord'`

#### Storage requirements
- Preformat storage device with a single partition either FAT32/NTFS/EXT{2,3,4} 
- A folder "Recordings" will be created on the root folder of the storage.
- Once the storage is adopted it will also create "Recordings/.active" with device ID and timestamp and mountpoint appended.
- If "recordings/.active" is present on insert, reuse this device.
- If partition numbers is less then or more then 1 the script will exit
- Freespace check is at least 2000MB and 10% of the total storage. Same goes for local storage (backup)

#### Failsafe checks
-

#### Log files
- /var/tmp/dietpi/logs/{dietpi-automation_custom_script.log,dietpi-firstboot.log,dietpi-firstrun-setup.log,dietpi-update.log,fs_partition_resize.log}
- /var/log/{audio-recording.log,audio-install.log,usb-automount.log}

#### Dirs
- /opt/rpi-audio
