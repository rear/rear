# Exclude everything non-essential

COPY_AS_IS_EXCLUDE+=( /etc/ssl /etc/udev/rules.d/*.rules )
COPY_AS_IS_EXCLUDE+=( /lib/systemd/systemd-cryptsetup )
COPY_AS_IS_EXCLUDE+=( /usr/lib/grub /usr/share/grub )
COPY_AS_IS_EXCLUDE+=( "$REAR_DIR_PREFIX" )

Log "Before exclusion: PROGS=(${PROGS[*]})"
PROGS=( $(printf '%s\n' "${PROGS[@]}" | sed -r '/^(btrfs|cryptsetup|dhclient|fsck|grub|mkfs|nslookup|scp|sftp|ssh|strace)/d') )
Log "After exclusion: PROGS=(${PROGS[*]})"
