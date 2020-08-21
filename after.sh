#! /bin/bash

funerror(){
    dialog --title $1 --textbox errorfile 20 60
    exit $2
}

ADMIN_USER=$(dialog --output-fd 1 --title "User_Config" --no-cancel --inputbox "User name:" 12 35)
useradd -m -G wheel ${ADMIN_USER}

ADMIN_USER_PASSWD=$(dialog --output-fd 1 --title "User_Config" --no-cancel --inputbox "User password:" 12 35)
chpasswd <<EOF
${ADMIN_USER}:${ADMIN_USER_PASSWD}
EOF
sed -i "s/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g" /etc/sudoers

dialog --title "Iptables_config" --yesno "Enable Iptables?" 12 35 && ENABLE_IPTABLES="true" || ENABLE_IPTABLES="false"
if [ ${ENABLE_IPTABLES} = "true" ]
then
    cp ./configfile/iptables.rules /etc/iptables/iptables.rules
    cp ./configfile/ip6tables.rules /etc/iptables/ip6tables.rules
    systemctl enable iptables ip6tables &> /dev/null
fi


DESKTOP_ENV=$(dialog --output-fd 1 --title "Select_Desktop" --menu "Select a Desktop" 12 35 5 1 no-desktop 2 XFCE 3 KDE 4 GNOME)
if [ ${DESKTOP_ENV} != "1" ]
then
    dialog --title "Installing" --infobox "Installing GPU drive, please wait" 12 35
    NVIDIA=0
    INTEL=0
    tmp1=$(lspci | grep -i vga | grep -i nvidia >> /dev/null)
    if [ $? -eq 0 ]
    then
        NVIDIA=1
        pacman -S nvidia --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
    fi
    tmp1=$(lspci | grep -i vga | grep -i intel >> /dev/null)
    if [ $? -eq 0 ]
    then
        INTEL=1
        pacman -S mesa vulkan-intel libva-intel-driver intel-media-driver --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
    fi
    if [ ${NVIDIA} -eq 1 -a ${INTEL} -eq 1 ]
    then
        pacman -S nvidia-prime --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
    fi
    dialog --title "Installing" --infobox "Installing xorg, please wait" 12 35
    pacman -S xorg --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
    dialog --title "Installing" --infobox "Installing Chinese fonts, please wait" 12 35
    pacman -S wqy-bitmapfont wqy-microhei wqy-zenhei --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
    echo "LANG=zh_CN.UTF-8
LC_COLLATE=C" > /etc/locale.conf


    if [ ${DESKTOP_ENV} = "2" ]
    then
        dialog --title "Installing" --infobox "Installing xfce4, please wait" 12 35
        arch-chroot /mnt pacman -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings network-manager-applet pavucontrol pulseaudio --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
        systemctl enable lightdm &> /dev/null
    fi


    if [ ${DESKTOP_ENV} = "3" ]
    then
        dialog --title "Installing" --infobox "Installing kde, please wait" 12 35
        pacman -S plasma dolphin konsole --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
        pacman -S appstream appstream-qt archlinux-appstream-data --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
        systemctl enable sddm &> /dev/null
    fi

    if [ ${DESKTOP_ENV} = '4' ]
    then
        dialog --title "Installing" --infobox "Installing gnome, please wait" 12 35
        pacman -S gnome --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
        systemctl enable gdm &> /dev/null
    fi
fi

dialog --title "ARCHLINUXCN_config" --yesno "Enable archlinuxcn?" 12 35 && ARCHLINUXCN="true" || ARCHLINUXCN="false"
if [ ${ARCHLINUXCN} = "true" ]
then
    dialog --title "Configuring" --infobox "Configuring archlinuxcn, please wait" 12 35
    pacman -S haveged --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
    systemctl enable haveged &> /dev/null
    rm -rf /etc/pacman.d/gnupg &> /dev/null
    pacman-key --init &> /dev/null
    pacman-key --populate archlinux &> /dev/null
    cat >> /etc/pacman.conf <<EOF
[archlinuxcn]
Include = /etc/pacman.d/archlinuxcnlist
EOF

    echo 'Server = https://mirrors.bfsu.edu.cn/archlinuxcn/$arch' >> /etc/pacman.d/archlinuxcnlist
    pacman -Syu &> /dev/null
    pacman -S archlinuxcn-keyring --noconfirm 1> /dev/null 2> ./errorfile || funerror "pacmanerror" 2
fi
dialog --title "Thanks" --yesno "Install Archlinux Successful\nThanks for using this script\nMy blog: https://blog.jinjiang.fun\nReboot now?" 15 40 && reboot || exit 0
