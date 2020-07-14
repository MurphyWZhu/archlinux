#! /bin/bash

source config
setfont /usr/share/kbd/consolefonts/iso01-12x22.psfu.gz
ping -c 4 blog.jinjiang.fun >> /dev/null
if [ $? -ne 0 ]
then
    echo "Network config error!"
    exit 1
fi

timedatectl set-ntp true

ls /sys/firmware/efi/efivars >> /dev/null
if [ $? -eq 0 ]
then
    boot_mode="uefi"
else
    boot_mode="bios"
fi

echo "Your computer boot mode:${boot_mode}"
echo "Disk Settings..."
if [ $boot_mode = "uefi" ]
then
    parted -s /dev/${DISK} mklabel gpt 
    parted -s /dev/${DISK} mkpart ESP fat32 1M 513M 
    parted -s /dev/${DISK} set 1 boot on 
    parted -s /dev/${DISK} mkpart primart ext4 513M 100%
    mkfs.fat -F32 /dev/${DISK}1 &> /dev/null
    mkfs.ext4 /dev/${DISK}2 >> /dev/null
    mount /dev/${DISK}2 /mnt
    mkdir /mnt/boot
    mount /dev/${DISK}1 /mnt/boot
else
    parted -s /dev/${DISK} mklabel msdos 
    parted -s /dev/${DISK} mkpart primary ext4 1M 100% 
    parted -s /dev/${DISK} set 1 boot on 
    mkfs.ext4 /dev/${DISK}1 >> /dev/null
    mount /dev/${DISK}1 /mnt
fi
echo "done."

echo 'Server = https://mirrors.bfsu.edu.cn/archlinux/$repo/os/$arch
Server = http://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist
echo "Archlinux base packages installing."
echo "Plase wait..."
pacstrap /mnt base base-devel linux linux-firmware vim networkmanager >> /dev/null

genfstab -U /mnt >> /mnt/etc/fstab
echo "Localozation Settings..."
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
arch-chroot /mnt hwclock --systohc
echo "echo 'en_US.UTF-8 UTF-8
zh_CN.UTF-8 UTF-8
zh_TW.UTF-8 UTF-8
zh_HK.UTF-8 UTF-8' >> /etc/locale.gen" | arch-chroot /mnt &> /dev/null

arch-chroot /mnt locale-gen >> /dev/null
echo "echo 'LANG=en_US.UTF-8' >> /etc/locale.conf" | arch-chroot /mnt &> /dev/null
echo "done."

echo "Configuring Network..."
echo "echo '${HOST_NAME}' >> /etc/hostname" | arch-chroot /mnt &> /dev/null
echo "echo '127.0.0.1    localhost
::1    localhost
127.0.1.1    ${HOST_NAME}.localdomain    ${HOST_NAME}' >> /etc/hosts" | arch-chroot /mnt &> /dev/null
echo "done."
echo "echo "root:${ROOT_PASSWD}" | chpasswd" | arch-chroot /mnt &> /dev/null

cat /proc/cpuinfo | grep name | grep Intel >> /dev/null
if [ $? -eq 0 ]
then
    echo "Intel CPU has been detected on your compuert"
    echo "Installing Intel CPU microcode..."
    arch-chroot /mnt pacman -S intel-ucode --noconfirm >> /dev/null
    echo "done."
fi
if [ $boot_mode = "uefi" ]
then
    echo "Installing and configuring grub...."
    arch-chroot /mnt pacman -S grub efibootmgr --noconfirm >> /dev/null
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB >> /dev/null
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg >> /dev/null
    echo "done."
    #echo "umounting disks..."
    #umount /mnt/boot
    #umount /mnt
    #echo "done."
else
    echo "Installing and configuring grub...."
    arch-chroot /mnt pacman -S grub --noconfirm >> /dev/null
    arch-chroot /mnt grub-install --target=i386-pc /dev/${DISK} >> /dev/null
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg >> /dev/null
    echo "done."
    #echo "umounting disks..."
    #umount /mnt
    #echo 'done.'
fi


if [ ${DESKTOP_ENV} != "none" ]
then
    lspci | grep -i vga | grep -i nvidia
    if [ $? -eq 0 ]
    then
        NVIDIA=1
	arch-chroot /mnt pacman -S nvidia --noconfirm >> /dev/null
    fi
    lspci | grep -i vga | grep -i intel
    if [ $? -eq 0 ]
    then
        INTEL=1
	arch-chroot /mnt pacman -S mesa vulkan-intel intel-media-driver libva-intel-driver --noconfirm >> /dev/null
    fi
    if [ ${NVIDIA} -eq 1 -a ${INTEL} -eq 1 ]
    then
        arch-chroot /mnt pacman -S nvidia-prime --noconfirm >> /dev/null
    fi

    arch-chroot /mnt pacman -S xorg --noconfirm >> /dev/null
    arch-chroot /mnt pacman -S wqy-bitmapfont wqy-microhei wqy-zenhei --noconfirm >> /dev/null
    echo "echo 'LANG=zh_CN.UTF-8
    LC_COLLATE=C' >> /etc/locale.conf" | arch-chroot /mnt &> /dev/null

    if [ ${DESKTOP_ENV} = "xfce4" ]
    then
        arch-chroot /mnt pacman -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter light-gtk-greeter-settings network-manager-applet pavucontrol pulseaudio --noconfirm >> /dev/null
	arch-chroot /mnt systemctl enable lightdm >> /dev/null
    fi

    if [ ${DESKTOP_ENV} = "kde" ]
    then
        arch-chroot /mnt pacman -S plasma dolphin konsole --noconfirm >> /dev/null
	arch-chroot /mnt systemctl enable sddm >> /dev/null
fi

arch-chroot /mnt systemctl enable NetworkManager >> /dev/null

umount /mnt/boot
umount /mnt
echo 'Install Archlinux Successful!'
echo 'Thank you for using this script!'
echo 'My blog:   https://blog.jinjiang.fun'
echo 'Plase remove your USB and reboot your computer'
    

