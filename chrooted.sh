#!/bin/sh

# source the transfered values
. /values

source /etc/profile

mount $BOOTPARTITION /boot

emerge-webrsync
emerge --sync --quiet

eselect news read
eselect news purge

eselect profile set default/linux/amd64/17.1
emerge -vuDU @world

# Timezone

echo "America/Vancouver" > /etc/timezone
emerge --config sys-libs/timezone-data

# Locale

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

cd /

eselect locale set "en_US.UTF-8 UTF-8"
env-update && source /etc/profile && ./postenvupdate.sh
