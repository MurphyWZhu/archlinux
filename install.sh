#! /bin/bash

funerror(){
    dialog --title $1 --textbox errorfile 20 60
    exit $2
}
setfont /usr/share/kbd/consolefonts/iso01-12x22.psfu.gz
ping -c 4 blog.jinjiang.fun 1> /dev/null 2> ./errorfile || funerror "NetworkError!" 1

timedatectl set-ntp true &> /dev/null

ls /sys/firmware/efi/efivars &> /dev/null && boot_mode="uefi" || boot_mode="bios"
DISK_NUM=$(dialog --output-fd 1 --title "Select a Disk" --menu "Select a Disk" 12 35 5 $(lsblk | grep disk | awk '{print(FNR,$1)}' | xargs))
DISK=$(lsblk | grep disk | awk '{print($1)}' | sed -n ${DISK_NUM}p)
dialog --title "Warning" --yesno "use this script to empty the installation disk" 12 35 || exit 0
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

echo 'Server = https://mirrors.bfsu.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/$repo/os/$arch
Server = https://mirrors.ustc.edu.cn/archlinux/$repo/os/$arch
Server = https://mirror.bjtu.edu.cn/disk3/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist

dialog --title "Installing" --infobox "Installation in progress, please wait" 12 35
pacstrap /mnt base base-devel linux linux-firmware vim networkmanager 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2

genfstab -U /mnt >> /mnt/etc/fstab
arch-chroot /mnt ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
arch-chroot /mnt hwclock --systohc
echo 'en_US.UTF-8 UTF-8
zh_CN.UTF-8 UTF-8
zh_TW.UTF-8 UTF-8
zh_HK.UTF-8 UTF-8' >> /mnt/etc/locale.gen

arch-chroot /mnt locale-gen >> /dev/null
echo 'LANG=en_US.UTF-8' >> /mnt/etc/locale.conf

HOST_NAME=$(dialog --output-fd 1 --title "Hostname_Config" --no-cancel  --inputbox "Hostname:" 12 35)
echo "${HOST_NAME}" >> /mnt/etc/hostname
echo "127.0.0.1    localhost
::1    localhost
127.0.1.1    ${HOST_NAME}.localdomain    ${HOST_NAME}" >> /mnt/etc/hosts
arch-chroot /mnt systemctl enable NetworkManager &> /dev/null 

ROOT_PASSWD=$(dialog --output-fd 1 --title "Password_Config" --no-cancel --inputbox "Root password:" 12 35)
arch-chroot /mnt chpasswd <<EOF
root:${ROOT_PASSWD}
EOF
tmp1=$(cat /proc/cpuinfo | grep name | grep Intel >> /dev/null)
if [ $? -eq 0 ]
then
    dialog --title "Installing" --infobox "Installing intel-ucode, please wait" 12 35
    arch-chroot /mnt pacman -S intel-ucode --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
fi


if [ $boot_mode = "uefi" ]
then    
    dialog --title "Installing" --infobox "Installing and Configuring GRUB, please wait" 12 35
    arch-chroot /mnt pacman -S grub efibootmgr --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB 1> /dev/null 2> ./errorfile || funerror "grub-installerror" 8
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg 1> /dev/null 2> ./errorfile || funerror "grub-mkconfigerror" 9
else
    dialog --title "Installing" --infobox "Installing and Configuring GRUB, please wait" 12 35
    arch-chroot /mnt pacman -S grub --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
    arch-chroot /mnt grub-install --target=i386-pc /dev/${DISK} 1> /dev/null 2> ./errorfile || funerror "grub-installerror" 8
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg 1> /dev/null 2> errorfile || funerror "grub-mkconfigerror" 9
fi


ADMIN_USER=$(dialog --output-fd 1 --title "User_Config" --no-cancel --inputbox "User name:" 12 35)
arch-chroot /mnt useradd -m -G wheel ${ADMIN_USER}

ADMIN_USER_PASSWD=$(dialog --output-fd 1 --title "User_Config" --no-cancel --inputbox "User password:" 12 35)
arch-chroot /mnt chpasswd <<EOF
${ADMIN_USER}:${ADMIN_USER_PASSWD}
EOF
arch-chroot /mnt sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g" /etc/sudoers

dialog --title "Iptables_config" --yesno "Enable Iptables?" 12 35 && ENABLE_IPTABLES="true" || ENABLE_IPTABLES="false"
if [ ${ENABLE_IPTABLES} = "true" ]
then
    cat > /mnt/etc/iptables/iptables.rules <<EOF
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
EOF

    cat > /mnt/etc/iptables/ip6tables.rules <<EOF
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
EOF
    arch-chroot /mnt systemctl enable iptables ip6tables &> /dev/null
fi



DESKTOP_ENV=$(dialog --output-fd 1 --title "Select_Desktop" --menu "Select a Desktop" 12 35 5 1 no-desktop 2 xfce 3 kde 4 gnome)
if [ ${DESKTOP_ENV} != "1" ]
then
    dialog --title "Installing" --infobox "Installing GPU drive, please wait" 12 35
    NVIDIA=0
    INTEL=0
    tmp1=$(lspci | grep -i vga | grep -i nvidia >> /dev/null)
    if [ $? -eq 0 ]
    then
        NVIDIA=1
        arch-chroot /mnt pacman -S nvidia --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
    fi
    tmp1=$(lspci | grep -i vga | grep -i intel >> /dev/null)
    if [ $? -eq 0 ]
    then
        INTEL=1
        arch-chroot /mnt pacman -S mesa vulkan-intel libva-intel-driver intel-media-driver --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
    fi

    if [ ${NVIDIA} -eq 1 -a ${INTEL} -eq 1 ]
    then
        arch-chroot /mnt pacman -S nvidia-prime --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
    fi
    dialog --title "Installing" --infobox "Installing xorg, please wait" 12 35
    arch-chroot /mnt pacman -S xorg --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
    dialog --title "Installing" --infobox "Installing Chinese fonts, please wait" 12 35
    arch-chroot /mnt pacman -S wqy-bitmapfont wqy-microhei wqy-zenhei --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
    echo "LANG=zh_CN.UTF-8
LC_COLLATE=C" > /mnt/etc/locale.conf


    if [ ${DESKTOP_ENV} = "2" ]
    then
        dialog --title "Installing" --infobox "Installing xfce4, please wait" 12 35
        arch-chroot /mnt pacman -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings network-manager-applet pavucontrol pulseaudio --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
        arch-chroot /mnt systemctl enable lightdm &> /dev/null
    fi


    if [ ${DESKTOP_ENV} = "3" ]
    then
        dialog --title "Installing" --infobox "Installing kde, please wait" 12 35
        arch-chroot /mnt pacman -S plasma dolphin konsole --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
        arch-chroot /mnt pacman -S appstream appstream-qt archlinux-appstream-data --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
        arch-chroot /mnt systemctl enable sddm &> /dev/null
    fi

    if [ ${DESKTOP_ENV} = '4' ]
    then
        dialog --title "Installing" --infobox "Installing gnome, please wait" 12 35
        arch-chroot /mnt pacman -S gnome --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
        arch-chroot /mnt systemctl enable gdm &> /dev/null
    fi
fi

dialog --title "ARCHLINUXCN_config" --yesno "Enable archlinuxcn?" 12 35 && ARCHLINUXCN="true" || ARCHLINUXCN="false"
if [ ${ARCHLINUXCN} = "true" ]
then
    dialog --title "Configuring" --infobox "Configuring archlinuxcn, please wait" 12 35
    arch-chroot /mnt pacman -S haveged --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
    arch-chroot /mnt systemctl enable haveged &> /dev/null
    arch-chroot /mnt rm -rf /etc/pacman.d/gnupg &> /dev/null
    arch-chroot /mnt pacman-key --init &> /dev/null
    arch-chroot /mnt pacman-key --populate archlinux &> /dev/null
    cat >> /mnt/etc/pacman.conf <<EOF
[archlinuxcn]
Include = /etc/pacman.d/archlinuxcnlist
EOF

    echo 'Server = https://mirrors.bfsu.edu.cn/archlinuxcn/$arch' >> /mnt/etc/pacman.d/archlinuxcnlist
    arch-chroot /mnt pacman -Syu &> /dev/null
    arch-chroot /mnt pacman -S archlinuxcn-keyring --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
fi

if [ ${boot_mode} = "uefi" ]
then
    umount /mnt/boot
fi
umount /mnt
dialog --title "Thanks" --yesno "Install Archlinux Successful\nThanks for using this script\nMy blog: https://blog.jinjiang.fun\nReboot now?" 15 40 && reboot || exit 0
