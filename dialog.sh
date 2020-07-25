#! /bin/bash
setfont /usr/share/kbd/consolefonts/iso01-12x22.psfu.gz
ping -c 4 blog.jinjiang.fun 1> /dev/null 2> ./errorfile 
DISK_NUM=$(dialog --output-fd 1 --title "Select a Disk" --menu "Select a Disk" 12 35 5 $(lsblk | grep disk | awk '{print(FNR,$1)}' | xargs))
DISK_NUM=$(cat tmp) 
DISK_NAME=$(lsblk | grep disk | awk '{print($1)}' | sed -n ${DISK_NUM}p)
dialog --title "W" --yesno "W:" 12 15
#parted ....

#install ...
dialog --title "Installing" --infobox "Installation in progress, please wait" 12 35
pacs

