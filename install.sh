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
# Pre-chroot

# Source the functions
. /root/gentoomatic/functions

# Source the colors
. /root/gentoomatic/colors

[ ! -d /sys/firmware/efi/efivars ] && "Non UEFI system detected. Please use an UEFI system and re run." && exit 1

mkdir -p /mnt/gentoo

CPUTHREADS=$(grep -c processor /proc/cpuinfo)

# Choices
choice "Enter hostname" "" HOSTNAME
choice "Enter normal user's name" "" USERNAME
choice "Do you want to follow the unstable branch (~amd64)" "yn" UNSTABLE

if [[ "$UNSTABLE" = "y" ]]; then
   choice "Do you want to use the latest gcc" "yn" LATESTGCC
fi

choice "Do you want a binary kernel" "yn" BINARYKERNEL
choice "Do you want to use all the flags" "yn" ALLFLAGS
choice "Do you want to use all $CPUTHREADS threads" "yn" ALLTHREADS

if [[ "$ALLTHREADS" = "n" ]]; then
   choice "How many threads do you want to use" "" HOWMANYTHREADS
   CPUTHREADS=$HOWMANYTHREADS
fi


lsblk
choice "What is your drive name" "" DRIVELOCATION

# Runs the disk partioning program
clear
info "Partitioning the drive"
DRIVEPATH="/dev/$DRIVELOCATION"
wipefs -a $DRIVEPATH
parted -a optimal $DRIVEPATH --script mklabel gpt
parted $DRIVEPATH --script mkpart primary 1MiB 513MiB
parted $DRIVEPATH --script name 1 boot
parted $DRIVEPATH --script -- mkpart primary 513MiB -1
parted $DRIVEPATH --script name 2 rootfs
parted $DRIVEPATH --script set 1 boot on

# Makes the filesystems
NVMETEXT=$(echo $DRIVEPATH | cut -d'/' -f3 | cut -c 1-4)
[ "$NVMETEXT" = "nvme" ] && PARTENDING="p" || PARTENDING=""

info "Making the filesystems"
mkfs.fat -F 32 /dev/${DRIVELOCATION}${PARTENDING}1 >/dev/null 2>&1
mkfs.ext4 /dev/${DRIVELOCATION}${PARTENDING}2 >/dev/null 2>&1
BOOTPARTITION="/dev/${DRIVELOCATION}${PARTENDING}1"
ROOTPARTITION="/dev/${DRIVELOCATION}${PARTENDING}2"

info "Mounting root partion"
mount $ROOTPARTITION /mnt/gentoo

# Downloading the tarball
info "Downloading tarball"

STAGE3_PATH_URL=http://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64.txt
STAGE3_PATH=$(curl -s $STAGE3_PATH_URL | grep -v "^#" | cut -d" " -f1)
STAGE3_URL=http://distfiles.gentoo.org/releases/amd64/autobuilds/$STAGE3_PATH
cd /mnt/gentoo/
while [ 1 ]; do
	wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 $STAGE3_URL >/dev/null 2>&1
	if [ $? = 0 ]; then break; fi;
	sleep 1s;
done;
check_file_exists () {
	file=$1
	if [ -e $file ]; then
		exists=true
	else
		printf "%s doesn't exist\n" $file
		wget --tries=20 $STAGE3_URL
		exists=false
		$2
	fi
}

check_file_exists /mnt/gentoo/stage3*
stage3=$(ls /mnt/gentoo/stage3*)

info "Unpacking tarball"
tar xpvf $stage3 --xattrs-include='*.*' --numeric-owner >/dev/null 2>&1

# Make.conf settings
info "Updating make.conf settings"
sed -i -e 's/COMMON_FLAGS=\"-O2\ -pipe\"/COMMON_FLAGS=\"-march=native\ -O2\ -pipe\"/g' /mnt/gentoo/etc/portage/make.conf

CPUTHREADSPLUSONE=$(( $CPUTHREADS + 1 ))
echo " " >> /mnt/gentoo/etc/portage/make.conf
echo "MAKEOPTS=\"-j$CPUTHREADSPLUSONE -l$CPUTHREADS\"" >> /mnt/gentoo/etc/portage/make.conf
echo "EMERGE_DEFAULT_OPTS=\"--jobs=$CPUTHREADSPLUSONE --load-average=$CPUTHREADS\"" >> /mnt/gentoo/etc/portage/make.conf
echo "PORTAGE_NICENESS=\"19\"" >> /mnt/gentoo/etc/portage/make.conf
echo "FEATURES=\"candy fixlafiles unmerge-orphans parallel-install\"" >> /mnt/gentoo/etc/portage/make.conf
[ "$ALLFLAGS" = "y" ] && echo "USE=\"X xinerama policykit pulseaudio dbus xft elogind networkmanager -wayland -kde -gnome -consolekit -systemd\"" >> /mnt/gentoo/etc/portage/make.conf
[ "$UNSTABLE" = "y" ] && echo "ACCEPT_KEYWORDS=\"~amd64\"" >> /mnt/gentoo/etc/portage/make.conf || echo "ACCEPT_KEYWORDS=\"amd64\"" >> /mnt/gentoo/etc/portage/make.conf

info "Copying repos.conf and resolv.conf"
mkdir --parents /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/

info "Mounting everything for the chroot environment"
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --make-rslave /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --make-rslave /mnt/gentoo/dev
test -L /dev/shm && rm /dev/shm && mkdir /dev/shm
mount --types tmpfs --options nosuid,nodev,noexec shm /dev/shm
chmod 1777 /dev/shm

# transfer some values into the chroot environment

touch /mnt/gentoo/values
cp /root/gentoomatic/chrooted.sh /mnt/gentoo
cp /root/gentoomatic/postenvupdate.sh /mnt/gentoo
cp /root/gentoomatic/colors /mnt/gentoo
cp /root/gentoomatic/functions /mnt/gentoo
echo "BOOTPARTITION=\"/dev/${DRIVELOCATION}${PARTENDING}1\"" > /mnt/gentoo/values
echo "ROOTPARTITION=\"/dev/${DRIVELOCATION}${PARTENDING}2\"" >> /mnt/gentoo/values
echo "HOSTNAME=\"$HOSTNAME\"" >> /mnt/gentoo/values
echo "USERNAME=\"$USERNAME\"" >> /mnt/gentoo/values
echo "BINARYKERNEL=\"$BINARYKERNEL\"" >> /mnt/gentoo/values
echo "DRIVELOCATION=\"$DRIVEPATH\"" >> /mnt/gentoo/values
echo "CPUTHREADS=\"$CPUTHREADS\"" >> /mnt/gentoo/values
echo "CPUTHREADSPLUSONE=\"$CPUTHREADSPLUSONE\"" >> /mnt/gentoo/values
echo "LATESTGCC=\"$LATESTGCC\"" >> /mnt/gentoo/values

info "Entering the chroot environment"
chroot /mnt/gentoo ./chrooted.sh && rm /mnt/gentoo/{chrooted.sh,postenvupdate.sh,colors,functions,values} && rm $stage3
