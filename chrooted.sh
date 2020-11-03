#!/bin/sh

info () {
    echo "[INFO] $1"
}

choice () {
    [ "$2" = "yn" ] && ENDING=" [y/n]? " || ENDING=": "
    read -p "[CHOICE] $1$ENDING" $3
}

# source the transfered values
. /values

source /etc/profile

mount $BOOTPARTITION /boot

info "Running emerge-webrsync."
emerge-webrsync >/dev/null 2>&1
info "Running emerge --sync."
emerge --sync >/dev/null 2>&1

info "Deleting all news."
eselect news read >/dev/null 2>&1
eselect news purge >/dev/null 2>&1

info "Settings the profile."
eselect profile set default/linux/amd64/17.1 >/dev/null 2>&1
info "Running the big emerge."
emerge -vuDU --autounmask-continue @world

# Timezone

info "Setting timezone."
echo "America/Vancouver" > /etc/timezone
emerge --config sys-libs/timezone-data >/dev/null 2>&1

# Locale

info "Setting locale."
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen >/dev/null 2>&1

cd /
eselect locale set en_US.utf8 >/dev/null 2>&1

info "Entering the post env-update section."
env-update >/dev/null 2>&1 && source /etc/profile && ./postenvupdate.sh
