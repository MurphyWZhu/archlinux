#! /bin/bash

funerror(){
    whiptail --title $1 --textbox errorfile 20 60
    exit $2
}

cp ./configfile/mirrorslist /etc/pacman.d/mirrorlist
setfont /usr/share/kbd/consolefonts/iso01-12x22.psfu.gz
ping -c 4 www.baidu.com 1> /dev/null 2> ./errorfile || funerror "NetworkError!" 1

timedatectl set-ntp true &> /dev/null

ls /sys/firmware/efi/efivars &> /dev/null && boot_mode="uefi" || boot_mode="bios"
DISK_NUM=$(whiptail --title "Select a Disk" --menu "Select a Disk" 12 35 5 $(lsblk | grep disk | awk '{print(FNR,$1)}' | xargs) 3>&1 1>&2 2>&3)
DISK=$(lsblk | grep disk | awk '{print($1)}' | sed -n ${DISK_NUM}p)
whiptail --title "Warning" --yesno "use this script to empty the installation disk" 12 35 || exit 0
if [ $boot_mode = "uefi" ]
then
    parted -s /dev/${DISK} mklabel gpt 2> ./errorfile && parted -s /dev/${DISK} mkpart ESP fat32 1M 513M 2> ./errorfile && parted -s /dev/${DISK} set 1 boot on 2> ./errorfile && parted -s /dev/${DISK} mkpart primart ext4 513M 100% 2> ./errorfile || funerror "partederror" 3
    mkfs.fat -F32 /dev/${DISK}1 1> /dev/null 2> ./errorfile || funerror "mkfserror" 4
    mkfs.ext4 /dev/${DISK}2 1> /dev/null 2> ./errorfile || funerror "mkfserror" 4
    mount /dev/${DISK}2 /mnt && mkdir /mnt/boot && mount /dev/${DISK}1 /mnt/boot
else
    parted -s /dev/${DISK} mklabel msdos 2> ./errorfile && parted -s /dev/${DISK} mkpart primary ext4 1M 100% 2> ./errorfile && parted -s /dev/${DISK} set 1 boot on 2> ./errorfile ||  funerror "partederror" 3
    mkfs.ext4 /dev/${DISK}1 1> /dev/null 2> ./errorfile || funerror "mkfserror" 4
    mount /dev/${DISK}1 /mnt
fi


whiptail --title "Installing" --infobox "Installation in progress, please wait" 12 35
pacstrap /mnt base base-devel linux linux-firmware vim networkmanager 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2

genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
arch-chroot /mnt hwclock --systohc
cp ./configfile/locale.gen /mnt/etc/locale.gen

arch-chroot /mnt locale-gen >> /dev/null
echo 'LANG=en_US.UTF-8' >> /mnt/etc/locale.conf

HOST_NAME=$(whiptail --title "Hostname_Config" --nocancel  --inputbox "Hostname:" 12 35 3>&1 1>&2 2>&3)
echo "${HOST_NAME}" >> /mnt/etc/hostname
echo "127.0.0.1    localhost
::1    localhost
127.0.1.1    ${HOST_NAME}.localdomain    ${HOST_NAME}" >> /mnt/etc/hosts
arch-chroot /mnt systemctl enable NetworkManager &> /dev/null 

ROOT_PASSWD=$(whiptail --title "Password_Config" --nocancel --inputbox "Root password:" 12 35 3>&1 1>&2 2>&3)
arch-chroot /mnt chpasswd <<EOF
root:${ROOT_PASSWD}
EOF
tmp1=$(cat /proc/cpuinfo | grep name | grep Intel >> /dev/null)
if [ $? -eq 0 ]
then
    whiptail --title "Installing" --infobox "Installing intel-ucode, please wait" 12 35
    arch-chroot /mnt pacman -S intel-ucode --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
else
    whiptail --title "Installing" --infobox "Installing amd-ucode, please wait" 12 35
    arch-chroot /mnt pacman -S amd-ucode --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
fi


if [ $boot_mode = "uefi" ]
then    
    whiptail --title "Installing" --infobox "Installing and Configuring GRUB, please wait" 12 35
    arch-chroot /mnt pacman -S grub efibootmgr --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB 1> /dev/null 2> ./errorfile || funerror "grub-installerror" 8
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg 1> /dev/null 2> ./errorfile || funerror "grub-mkconfigerror" 9
else
    whiptail --title "Installing" --infobox "Installing and Configuring GRUB, please wait" 12 35
    arch-chroot /mnt pacman -S grub --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
    arch-chroot /mnt grub-install --target=i386-pc /dev/${DISK} 1> /dev/null 2> ./errorfile || funerror "grub-installerror" 8
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg 1> /dev/null 2> errorfile || funerror "grub-mkconfigerror" 9
fi
mkdir /mnt/root/install
cp -r ./* /mnt/root/install/
whiptail --title "Reboot" --yesno "Install Archlinux Successful\nIf you want to do the following\nPlease Reboot and Run:\n    cd /root/install\n    chmod +x after.sh\n    ./after.sh\nReboot now?" 15 40 && reboot || exit 0
if [ ${boot_mode} = "uefi" ]
then
    umount /mnt/boot
fi
umount /mnt
