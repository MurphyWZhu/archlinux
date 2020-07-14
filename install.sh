#! /bin/bash
ping -c 4 blog.jinjiang.fun >> /dev/null
if [ $? -nt 0 ]
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

if [ $boot_mode = "uefi" ]
then
    parted -s /dev/vda mklabel gpt 
    parted -s /dev/vda mkpart ESP fat32 1M 513M 
    parted -s /dev/vda set 1 boot on 
    parted -s /dev/vda mkpart primart ext4 513M 100%
    mkfs.fat -F32 /dev/vda1 >> /dev/null
    mkfs.ext4 /dev/vda2 >> /dev/null
    mount /dev/vda2 /mnt
    mkdir /mnt/boot
    mount /dev/vda1 /mnt/boot
else
    parted -s /dev/vda mklabel msdos 
    parted -s /dev/vda mkpart primary ext4 1M 100% 
    parted -s /dev/vda set 1 boot on 
    mkfs.ext4 /dev/vda1 >> /dev/null
    mount /dev/vda1 /mnt
fi

echo 'Server = https://mirrors.bfsu.edu.cn/archlinux/$repo/os/$arch
Server = http://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist

pacstrap /mnt base base-devel linux linux-firmware vim networkmanager

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
arch-chroot /mnt hwclock --systohc
arch-chroot /mnt "echo 'en_US.UTF-8 UTF-8
zh_CN.UTF-8 UTF-8
zh_TW.UTF-8 UTF-8
zh_HK.UTF-8 UTF-8' >> /etc/locale.gen"

arch-chroot /mnt locale-gen
arch-chroot /mnt "echo 'LANG=en_US.UTF-8' >> /etc/locale.conf"
arch-chroot /mnt "echo 'karch' >> /etc/hostname"
arch-chroot /mnt "echo '127.0.0.1	localhost
::1		localhost
127.0.1.1	karch.localdomain	karch' >> /etc/hosts"
arch-chroot /mnt passwd
cat /proc/cpuinfo | grep name | grep Intel >> /dev/null
if [ $? -eq 0 ]
then
    arch-chroot /mnt "pacman -S intel-ucode --noconfirm"
fi
if [ $boot_mode = "uefi" ]
then
    arch-chroot /mnt pacman -S grub efibootmgr --noconfirm
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    umount /mnt/boot
    umount /mnt
else
    arch-chroot /mnt pacman -S grub --noconfirm
    arch-chroot /mnt grub-install --target=i386-pc /dev/vda
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
    umount /mnt
fi

echo 'Installed Archlinux!'
    

