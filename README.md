# rpi-audio
### Turnkey headless Raspberry Pi audio recorder with networking and UPS extensions 

#### Flash base image to SSD / SDCard
- [Download](https://www.balena.io/etcher/) and install Balena Etcher
- Download client RaspberryPI4 (8GB) (ARMv6) | [Download client RaspberryPI4 (8GB) (ARMv8) (64Bit)](https://nextcloud.waaromzomoeilijk.nl/s/rkWaBseReC3pxNf)
- Flash the image to an SD Card / SSD (recommended)
- Boot the RaspberryPI with Microphone inserted via USB
- Let the installation run and automatically reboot after install (SD card: X / SSD: less then 5 mins)
- Once its rebooted, insert USB drive (formatted to FAT32/EXT{2,3,4}/NTFS and only 1 partition) and the recording will start
- After this insert it will also start recording on boot
- Stop the recording from cli: `ps -cx -o pid,command | awk '$2 == "arecord" { print $1 }' | xargs kill -INT | wait`

#### Storage requirements
- Preformat storage device with a single partition either FAT32/NTFS/EXT{2,3,4} 
      * A folder "Recordings" will be created on the root folder of the storage.
      * Once the storage is adopted it will also create "Recordings/.active" with device ID and timestamp and mountpoint appended.
      * If "recordings/.active" is present on insert, reuse this device.
      * If partition numbers is less then or more then 1 the script will exit
      * Freespace check is at least 500MB and 10% of the total storage. Same goes for local storage (backup)
