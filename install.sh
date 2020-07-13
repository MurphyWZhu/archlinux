#! /bin/bash
ping -c 4 blog.jinjiang.com >> /dev/null
if [ $? -nt 0 ]
then
    echo "Network config error!"
    return 1
fi

timedatactl set-ntp true

ls /sys/firmware/efi/efivars >> /dev/null
if [ $? -eq 0 ]
then
    boot_mode="uefi"
else
    boot_mode="bios"
fi

if [ $boot_mode = "uefi" ]
then
    parted /dev/vda mklabel gpt mkpart ESP fat32 1M 513M set 1 boot on mkpart primart ext4 512M 100% >> /dev/null
    mkfs.fat -F32 /dev/vda1 >> /dev/null
    mkfs.ext4 /dev/vda2 >> /dev/null
    mount /dev/vda2 /mnt
    mkdir /mnt/boot
    mount /dev/vda1 /mnt/boot
else
    parted /dev/vda mklabel msdos mkpart primary ext4 1M 100% set 1 boot on >> /dev/null
    mkfs.ext4 /dev/vda1 >> /dev/null
    mount /dev/vda1 /mnt
fi

echo "Server = https://mirrors.bfsu.edu.cn/archlinux/$repo/os/$arch
Server = http://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch" > /etc/pacman.d/mirrorlist

pacstrap /mnt base base-devel linux linux-firmware vim networkmanager

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt

ls
