#! /bin/bash

source config
funerror(){
    exit $2
}
setfont /usr/share/kbd/consolefonts/iso01-12x22.psfu.gz
ping -c 4 blog.jinjiang.fun 1> /dev/null 2> ./errorfile || funerror "error:Network Error!" 1

timedatectl set-ntp true &> /dev/null

ls /sys/firmware/efi/efivars &> /dev/null && boot_mode="uefi" || boot_mode="bios"

echo "Your computer boot mode:${boot_mode}"
echo -e "Disk Settings.\c"
if [ $boot_mode = "uefi" ]
then
    parted -s /dev/${DISK} mklabel gpt 2> ./errorfile && parted -s /dev/${DISK} mkpart ESP fat32 1M 513M 2> ./errorfile && parted -s /dev/${DISK} set 1 boot on 2> ./errorfile && parted -s /dev/${DISK} mkpart primart ext4 513M 100% 2> ./errorfile || funerror "error:parted error" 3
    echo -e "..\c"
    mkfs.fat -F32 /dev/${DISK}1 1> /dev/null 2> ./errorfile || funerror "error:mkfs error" 4
    mkfs.ext4 /dev/${DISK}2 1> /dev/null 2> ./errorfile || funerror "error:mkfs error" 4
    echo -e "..\c"
    mount /dev/${DISK}2 /mnt && mkdir /mnt/boot && mount /dev/${DISK}1 /mnt/boot
else
    parted -s /dev/${DISK} mklabel msdos 2> ./errorfile && parted -s /dev/${DISK} mkpart primary ext4 1M 100% 2> ./errorfile && parted -s /dev/${DISK} set 1 boot on 2> ./errorfile ||  funerror "error:parted error" 3
    echo -e "..\c"
    mkfs.ext4 /dev/${DISK}1 1> /dev/null 2> ./errorfile || funerror "error:mkfs error" 4
    echo  -e "..\c"
    mount /dev/${DISK}1 /mnt
fi
echo -e ".\033[32mDone\033[0m\n"

echo 'Server = https://mirrors.bfsu.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch
Server = https://mirror.bjtu.edu.cn/disk3/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist

echo -e "Archlinux base packages installing.\c"
pacstrap /mnt base base-devel linux linux-firmware vim networkmanager 1> /dev/null 2> ./errorfile || funerror "error:pacman error" 2
echo -e "..\c"
sleep 2
echo -e "\033[32mDone\033[0m\n"

genfstab -U /mnt >> /mnt/etc/fstab
echo -e "Localozation Settings.\c"
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
arch-chroot /mnt hwclock --systohc
echo "echo 'en_US.UTF-8 UTF-8
zh_CN.UTF-8 UTF-8
zh_TW.UTF-8 UTF-8
zh_HK.UTF-8 UTF-8' >> /etc/locale.gen" | arch-chroot /mnt &> /dev/null

echo -e "..\c"
arch-chroot /mnt locale-gen >> /dev/null
echo -e "..\c"
echo "echo 'LANG=en_US.UTF-8' >> /etc/locale.conf" | arch-chroot /mnt &> /dev/null
echo -e ".\033[32mDone\033[0m\n"


echo -e "Configuring Network.\c"
echo "echo '${HOST_NAME}' >> /etc/hostname" | arch-chroot /mnt &> /dev/null
echo "echo '127.0.0.1    localhost
::1    localhost
127.0.1.1    ${HOST_NAME}.localdomain    ${HOST_NAME}' >> /etc/hosts" | arch-chroot /mnt &> /dev/null
echo -e "..\c"
arch-chroot /mnt systemctl enable NetworkManager &> /dev/null 
echo -e "..\c"
echo -e "\033[32mDone\033[0m\n"


echo "echo "root:${ROOT_PASSWD}" | chpasswd" | arch-chroot /mnt &> /dev/null


cat /proc/cpuinfo | grep name | grep Intel >> /dev/null
if [ $? -eq 0 ]
then
    echo "Intel CPU has been detected on your compuert"
    echo -e "Installing Intel CPU microcode..\c"
    arch-chroot /mnt pacman -S intel-ucode --noconfirm 1> /dev/null 2> ./errorfile || funerror "error:pacman error" 2
    echo -e "..\c"
    echo -e "\033[32mDone\033[0m\n"
    sleep 2
fi


if [ $boot_mode = "uefi" ]
then
    echo -e "Installing and configuring grub.\c"
    arch-chroot /mnt pacman -S grub efibootmgr --noconfirm 1> /dev/null 2> ./errorfile || funerror "error:pacman error" 2
    echo -e "..\c"
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB 1> /dev/null 2> ./errorfile || funerror "error:grub-install error" 8
    echo -e "..\c"
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg 1> /dev/null 2> ./errorfile || funerror "error:grub-mkconfig error" 9
    echo -e "..\c"
    sleep 2
    echo -e "\033[32mDone\033[0m\n"
else
    echo -e "Installing and configuring grub.\c"
    arch-chroot /mnt pacman -S grub --noconfirm 1> /dev/null 2> ./errorfile || funerror "error:pacman error" 2
    echo -e "..\c"
    arch-chroot /mnt grub-install --target=i386-pc /dev/${DISK} 1> /dev/null 2> ./errorfile || funerror "error:grub-install error" 8
    echo -e "..\c"
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg 1> /dev/null 2> errorfile || funerror "error:grub-mkconfig error" 9
    echo -e "..\c"
    sleep 2
    echo -e "\033[32mDone\033[0m\n"
fi


arch-chroot /mnt useradd -m -G wheel ${ADMIN_USER}
echo "echo '${ADMIN_USER}:${ADMIN_USER_PASSWD}' | chpasswd" | arch-chroot /mnt &> /dev/null
arch-chroot /mnt sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g" /etc/sudoers


if [ ${ENABLE_IPTABLES} = "true" ]
then
    echo -e "Settings iptables..\c"
    echo "cat > /etc/iptables/iptables.rules <<EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [11:1196]
:TCP - [0:0]
:UDP - [0:0]
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate INVALID -j DROP
-A INPUT -p icmp -m icmp --icmp-type 8 -m conntrack --ctstate NEW -j ACCEPT
-A INPUT -p udp -m conntrack --ctstate NEW -j UDP
-A INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -m conntrack --ctstate NEW -j TCP
-A INPUT -p udp -j REJECT --reject-with icmp-port-unreachable
-A INPUT -p tcp -j REJECT --reject-with tcp-reset
-A INPUT -j REJECT --reject-with icmp-proto-unreachable
COMMIT
EOF" | arch-chroot /mnt &> /dev/null

    echo "cat > /etc/iptables/ip6tables.rules <<EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]
:TCP - [0:0]
:UDP - [0:0]
-A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate INVALID -j DROP
-A INPUT -s fe80::/10 -p ipv6-icmp -j ACCEPT
-A INPUT -p udp -m conntrack --ctstate NEW -j UDP
-A INPUT -p tcp -m tcp --tcp-flags FIN,SYN,RST,ACK SYN -m conntrack --ctstate NEW -j TCP
-A INPUT -p udp -j REJECT --reject-with icmp6-adm-prohibited
-A INPUT -p tcp -j REJECT --reject-with tcp-reset
-A INPUT -j REJECT --reject-with icmp6-adm-prohibited
-A INPUT -p ipv6-icmp -m icmp6 --icmpv6-type 128 -m conntrack --ctstate NEW -j ACCEPT
COMMIT
EOF" | arch-chroot /mnt &> /dev/null
    echo -e "..\c"
    arch-chroot /mnt systemctl enable iptables ip6tables &> /dev/null
    echo -e "..\c"
    sleep 2
    echo -e "\033[32mDone\033[0m\n"
fi



if [ ${DESKTOP_ENV} != "none" ]
then
    echo "Your desktop environment of choice is ${DESKTOP_ENV}"
    NVIDIA=0
    INTEL=0
    lspci | grep -i vga | grep -i nvidia >> /dev/null
    if [ $? -eq 0 ]
    then
        NVIDIA=1
        echo "Your computer has an Nvidia graphics card"
        echo -e "Installing Nvidia drive.\c"
        arch-chroot /mnt pacman -S nvidia --noconfirm &> /dev/null || funerror "error:pacman error" 2
        echo -e "..\c"
	sleep 2
        echo -e "\033[32mDone\033[0m\n"
    fi
    lspci | grep -i vga | grep -i intel >> /dev/null
    if [ $? -eq 0 ]
    then
        INTEL=1
        echo "Your computer has an Intel graphics card"
        echo -e "Installing Intel drive.\c"
        arch-chroot /mnt pacman -S mesa vulkan-intel libva-intel-driver intel-media-driver --noconfirm &> /dev/null || funerror "error:pacman error" 2
        echo -e "..\c"
	sleep 2
        echo -e "\033[32mDone\033[0m\n"
    fi

    if [ ${NVIDIA} -eq 1 -a ${INTEL} -eq 1 ]
    then
        echo "Oh,Your computer has Intel GPU and Nvidia GPU"
        echo -e "So,Installing nvidia-prime..\c"
        arch-chroot /mnt pacman -S nvidia-prime --noconfirm &> /dev/null || funerror "error:pacman error" 2
        echo -e "..\c"
	sleep 2
        echo -e "\033[32mDone\033[0m\n"
    fi
    echo -e "Install xorg..\c"
    arch-chroot /mnt pacman -S xorg --noconfirm &> /dev/null || funerror "error:pacman error" 2
    echo -e "..\c"
    sleep 2
    echo -e "\033[32mDone\033[0m\n"

    echo -e "Install chinese fonts..\c"
    arch-chroot /mnt pacman -S wqy-bitmapfont wqy-microhei wqy-zenhei --noconfirm >> /dev/null || funerror "error:pacman error" 2
    echo -e "..\c"
    sleep 2
    echo -e "\033[32mDone\033[0m\n"
    echo "echo 'LANG=zh_CN.UTF-8
LC_COLLATE=C' > /etc/locale.conf" | arch-chroot /mnt &> /dev/null


    if [ ${DESKTOP_ENV} = "xfce4" ]
    then
        echo -e "Installing xfce4 desktop environment.\c"
        arch-chroot /mnt pacman -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings network-manager-applet pavucontrol pulseaudio --noconfirm &> /dev/null || funerror "error:pacman error" 2
        echo -e "..\c"
        arch-chroot /mnt systemctl enable lightdm &> /dev/null
        echo -e "..\c"
	sleep 2
        echo -e "\033[32mDone\033[0m\n"
    fi


    if [ ${DESKTOP_ENV} = "kde" ]
    then
        echo -e "Installing kde desktop environment.\c"
        arch-chroot /mnt pacman -S plasma dolphin konsole --noconfirm &> /dev/null || funerror "error:pacman error" 2
        echo -e "..\c"
        arch-chroot /mnt pacman -S appstream appstream-qt archlinux-appstream-data --noconfirm &> /dev/null || funerror "error:pacman error" 2
        echo -e "..\c"
        arch-chroot /mnt systemctl enable sddm &> /dev/null
        echo -e "..\c"
	sleep 2
        echo -e "\033[32mDone\033[0m\n"
    fi


    if [ ${DESKTOP_ENV} = 'gnome' ]
    then
        echo -e "Installing gnome desktop environment..\c"
        arch-chroot /mnt pacman -S gnome --noconfirm &> /dev/null || funerror "error:pacman error" 2
        echo -e "..\c"
        arch-chroot /mnt systemctl enable gdm &> /dev/null
        echo -e "..\c"
	sleep 2
        echo -e "\033[32mDone\033[0m\n"
    fi
fi

if [ ${ARCHLINUXCN} = "true" ]
then
    echo -e "Configuring Archlinuxcn.\c"
    arch-chroot /mnt pacman -S haveged --noconfirm &> /dev/null || funerror "error:pacman error" 2
    echo -e "..\c"
    arch-chroot /mnt systemctl enable haveged &> /dev/null
    sleep 1
    echo -e "..\c"
    arch-chroot /mnt rm -rf /etc/pacman.d/gnupg &> /dev/null
    arch-chroot /mnt pacman-key --init &> /dev/null
    echo -e "..\c"
    arch-chroot /mnt pacman-key --populate archlinux &> /dev/null
    echo -e "..\c"
    echo "cat >> /etc/pacman.conf <<EOF
[archlinuxcn]
Include = /etc/pacman.d/archlinuxcnlist
EOF" | arch-chroot /mnt &> /dev/null

    echo 'Server = https://mirrors.bfsu.edu.cn/archlinuxcn/$arch' >> /mnt/etc/pacman.d/archlinuxcnlist
    arch-chroot /mnt pacman -Syu &> /dev/null
    echo -e "..\c"
    arch-chroot /mnt pacman -S archlinuxcn-keyring --noconfirm &> /dev/null || funerror "error:pacman error" 2
    echo -e "..\c"
    echo -e "\033[32mDone\033[0m\n"
fi

echo -e "Installing other packages......\c"
arch-chroot /mnt pacman -S ${OTHER_PACKAGES} --noconfirm &> /dev/null || funerror "error:pacman error" 2
sleep 3
echo -e "\033[32mDone\033[0m\n"

if [ ${boot_mode} = "uefi" ]
then
    umount /mnt/boot
fi
umount /mnt
echo -e "\n\n\n"
echo -e "Install Archlinux \033[32mSuccessful!\033[0m\n"
echo -e "Thank you for using this script!\n"
echo -e "My blog:   \033[34mhttps://blog.jinjiang.fun\033[0m\n"
echo -e "Plase remove your USB and reboot your computer\n"
