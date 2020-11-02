#!/bin/sh

. /values

# fstab

echo -e "$BOOTPARTITION\t\t/boot\t\tvfat\t\tdefaults,noatime\t\t0 2" >> /etc/fstab
echo -e "$ROOTPARTITION\t\t/\t\text4\t\tnoatime\t\t0 1" >> /etc/fstab

emerge sys-kernel/installkernel-gentoo
emerge sys-kernel/gentoo-kernel-bin
emerge --autounmask-continue sys-kernel/linux-firmware

sed -i -e "s/hostname=\"localhost\"/hostname=\"$HOSTNAME\"/g" /etc/conf.d/hostname

emerge --noreplace net-misc/netifrc
emerge flaggie

flaggie networkmanager +dhclient

emerge net-misc/networkmanager
rc-update add NetworkManager default

# hosts

echo -e "127.0.0.1\t\t$HOSTNAME.homenetwork $HOSTNAME localhost" > /etc/hosts


emerge app-admin/sysklogd
rc-update add sysklogd default


emerge sys-process/cronie
rc-update add cronie default
crontab /etc/crontab

emerge sys-apps/mlocate

emerge sys-fs/e2fsprogs sys-fs/dosfstools

# grub
echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
emerge sys-boot/grub:2
grub-install --target=x86_64-efi --efi-directory=/boot
grub-mkconfig -o /boot/grub/grub.cfg

echo
echo "--------Set root password--------"
echo
passwd

echo
echo "--------SUCCESSFUL GENTOO INSTALLATION--------"
echo
echo "Please reboot"
echo
