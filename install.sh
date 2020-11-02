#!/usr/bin/env sh

mkdir /mnt/gentoo

lsblk
DRIVELOCATION=" "
read -p "[CHOICE] What is your drive name? " DRIVELOCATION

# Runs the disk partioning program

DRIVEPATH="/dev/$DRIVELOCATION"
wipefs -a $DRIVEPATH
parted -a optimal $DRIVEPATH --script mklabel gpt
parted $DRIVEPATH --script mkpart primary 1MiB 513MiB
parted $DRIVEPATH --script name 1 boot
parted $DRIVEPATH --script -- mkpart primary 513MiB -1
parted $DRIVEPATH --script name 2 rootfs
parted $DRIVEPATH --script set 1 boot on

# Makes the filesystems
ISNVME=" "
read -p "[CHOICE] Is your install drive an nvme device [y/n]? " ISNVME

PARTENDING=" "
[ "$ISNVME" = "y" ] && PARTENDING="p" || PARTENDING=""

mkfs.fat -F 32 /dev/${DRIVELOCATION}${PARTENDING}1
mkfs.ext4 /dev/${DRIVELOCATION}${PARTENDING}2

BOOTPARTITION="/dev/${DRIVELOCATION}${PARTENDING}1"
ROOTPARTITION="/dev/${DRIVELOCATION}${PARTENDING}2"

mount $ROOTPARTITION /mnt/gentoo

# Hostname

read -p "[CHOICE] Enter hostname: " HOSTNAME

# Downloading the tarball

GENTOO_TYPE=latest-stage3-amd64
STAGE3_PATH_URL=http://distfiles.gentoo.org/releases/amd64/autobuilds/$GENTOO_TYPE.txt
STAGE3_PATH=$(curl -s $STAGE3_PATH_URL | grep -v "^#" | cut -d" " -f1)
STAGE3_URL=http://distfiles.gentoo.org/releases/amd64/autobuilds/$STAGE3_PATH
touch /mnt/gentoo/gentootype.txt
echo $GENTOO_TYPE >> /mnt/gentoo/gentootype.txt
cd /mnt/gentoo/
while [ 1 ]; do
	wget --retry-connrefused --waitretry=1 --read-timeout=20 --timeout=15 -t 0 $STAGE3_URL
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
tar xpvf $stage3 --xattrs-include='*.*' --numeric-owner

# Make.conf settings
sed -i -e 's/COMMON_FLAGS=\"-02\ -pipe\"/COMMON_FLAGS=\"-march=native\ -02\ -pipe \"/g'

CPUTHREADS=$(grep processor /proc/cpuinfo | wc -l)
echo "MAKEOPTS=\"-j$CPUTHREADS -l$CPUTHREADS\"" >> /mnt/gentoo/etc/portage/make.conf
echo "EMERGE_DEFAULT_OPTS=\"--jobs=$CPUTHREADS --load-average=$CPUTHREADS\"" >> /mnt/gentoo/etc/portage/make.conf
echo "PORTAGE_NICENESS=\"19\"" >> /mnt/gentoo/etc/portage/make.conf
echo "FEATURES=\"candy fixlafiles unmerge-orphans parallel-install\"">> /mnt/gentoo/etc/portage/make.conf


mkdir --parents /mnt/gentoo/etc/portage/repos.conf
cp /mnt/gentoo/usr/share/portage/config/repos.conf /mnt/gentoo/etc/portage/repos.conf/gentoo.conf
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/


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
echo "BOOTPARTITION=\"/dev/${DRIVELOCATION}${PARTENDING}1\"" > /mnt/gentoo/values
echo "ROOTPARTITION=\"/dev/${DRIVELOCATION}${PARTENDING}2\"" >> /mnt/gentoo/values
echo "HOSTNAME=\"$HOSTNAME\"" >> /mnt/gentoo/values

chroot /mnt/gentoo ./chrooted.sh
