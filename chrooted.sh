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
# Post-chroot

# Source the functions
. /functions

# Source the colors
. /colors

# Source the values
. /values

source /etc/profile

mount $BOOTPARTITION /boot

info "Running emerge-webrsync"
emerge-webrsync >/dev/null 2>&1
info "Running emerge --sync"
emerge --sync >/dev/null 2>&1

info "Deleting all news"
eselect news read >/dev/null 2>&1
eselect news purge >/dev/null 2>&1

if [[ "$LATESTGCC" = "n" ]]; then
    mkdir -p /etc/portage/package.accept_keywords
    echo "sys-devel/gcc -~amd64" > /etc/portage/package.accept_keywords/gcc
fi

info "Emerge rust-bin"
emerge --autounmask-continue dev-lang/rust-bin

info "Settings the profile"
eselect profile set default/linux/amd64/17.1 >/dev/null 2>&1
info "Running the big emerge"
emerge -vuDU --autounmask-continue @world

info "Fixing perl"
perl-cleaner --modules

# Timezone
info "Setting timezone"
echo "America/Vancouver" > /etc/timezone
emerge --config sys-libs/timezone-data >/dev/null 2>&1

# Locale
info "Setting locale"
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen >/dev/null 2>&1

cd /
eselect locale set en_US.utf8 >/dev/null 2>&1

info "Entering the post env-update section."
env-update >/dev/null 2>&1 && source /etc/profile && ./postenvupdate.sh
