#!/bin/sh


#         -/oyddmdhs+:.
#      -odNMMMMMMMMNNmhy+-`
#    -yNMMMMMMMMMMMNNNmmdhy+-
#  `omMMMMMMMMMMMMNmdmmmmddhhy/`
#  omMMMMMMMMMMMNhhyyyohmdddhhhdo`
# .ydMMMMMMMMMMdhs   o/smdddhhhhdm+`
#  oyhdmNMMMMMMMNdyooydmddddhhhhyhNd.
#   :oyhhdNNMMMMMMMNNNmmdddhhhhhyymMh
#     .:+sydNMMMMMNNNmmmdddhhhhhhmMmy
#        /mMMMMMMNNNmmmdddhhhhhmMNhs:
#     `oNMMMMMMMNNNmmmddddhhdmMNhs+`
#   `sNMMMMMMMMNNNmmmdddddmNMmhs/.
#  /NMMMMMMMMNNNNmmmdddmNMNdso:`
# +MMMMMMMNNNNNmmmmdmNMNdso/-
# yMMNNNNNNNmmmmmNNMmhs+/-`
# /hMMNNNNNNNNMNdhs++/-`
# `/ohdmmddhys+++/:.`
#   `-//////:--.

# Gentoo install script made by Jackson
# Post-envupdate

# Source the functions
. /functions

# Source the colors
. /colors

# Source the values
. /values

# fstab

info "Generating the fstab"
echo -e "$BOOTPARTITION\t\t/boot\t\tvfat\t\tdefaults,noatime\t0 2" >> /etc/fstab
echo -e "$ROOTPARTITION\t\t/\t\text4\t\tnoatime\t\t0 1" >> /etc/fstab

if [[ "$BINARYKERNEL" = "y" ]]; then
    info "Installing the binary kernel"
    emerge --autounmask-continue sys-kernel/installkernel-gentoo sys-kernel/gentoo-kernel-bin sys-kernel/linux-firmware
else
    info "Installing the gentoo sources, pciutils, usbutils, genkernel, and linux-firmware"
    emerge --autounmask-continue sys-kernel/gentoo-sources sys-apps/pciutils sys-apps/usbutils sys-kernel/genkernel sys-kernel/linux-firmware
    cd /usr/src/linux
    make menuconfig
    clear
    make -j$CPUTHREADSPLUSONE
    make modules_install install
    genkernel --install --kernel-config=/usr/src/linux/.config initramfs
fi

info "Setting the hostname"
sed -i -e "s/hostname=\"localhost\"/hostname=\"$HOSTNAME\"/g" /etc/conf.d/hostname

emerge --noreplace net-misc/netifrc

info "Emerge flaggie"
emerge flaggie

info "Emerge NetworkManager"
emerge --autounmask-continue net-misc/networkmanager
rc-update add NetworkManager default

info "Creating the standard user"
useradd -m -G wheel,audio,video,portage,plugdev $USERNAME

# hosts

info "Setting the hosts file"
echo -e "127.0.0.1\t\t$HOSTNAME.homenetwork $HOSTNAME localhost" > /etc/hosts

info "Emerge sysklogd"
emerge app-admin/sysklogd
rc-update add sysklogd default >/dev/null 2>&1

info "Emerge cronie"
emerge sys-process/cronie
rc-update add cronie default >/dev/null 2>&1
crontab /etc/crontab >/dev/null 2>&1

info "Emerge mlocate"
emerge sys-apps/mlocate

info "Emerge fs progs"
emerge sys-fs/e2fsprogs sys-fs/dosfstools

# grub
echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
info "Emerge grub"
emerge sys-boot/grub:2
info "Installing grub"
grub-install --target=x86_64-efi --efi-directory=/boot
info "Generating grub config"
grub-mkconfig -o /boot/grub/grub.cfg

info "Emerge sudo, vim, git, layman and eix"
emerge --autounmask-continue app-admin/sudo app-editors/vim app-portage/eix dev-vcs/git app-portage/layman

git clone https://gitlab.com/jadecell/installscripts.git /home/$USERNAME/installscripts
chown -R $USERNAME:$USERNAME /home/$USERNAME/installscripts

echo " " >> /etc/sudoers
echo "## Main users permissions" >> /etc/sudoers
echo "$USERNAME ALL=(ALL) ALL" >> /etc/sudoers

cp /etc/rc.conf /etc/rc.conf.bak
sed -i -e 's/#rc_parallel="NO"/rc_parallel="YES"/g' /etc/rc.conf

clear
echo
echo -e "${YELLOW}--------Set ${RED}root${YELLOW} password--------${NC}"
echo
passwd

clear
echo
echo -e "${YELLOW}--------Set ${RED}$USERNAME${YELLOW}'s password--------${NC}"
echo
passwd $USERNAME

clear
echo
echo -e "${LIGHTGREEN}Successfully installed ${LIGHTMAGENTA}Gentoo${LIGHTGREEN}! ${RED}Reboot now.${NC}"
echo
