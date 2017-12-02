# Exclude everything non-essential

# bootloaders
COPY_AS_IS_EXCLUDE+=( /boot /etc/grub.d /etc/default/grub /usr/lib/grub /usr/share/grub )
# udev (hwdb.d files are compiled into binaries hwdb.bin by systemd-hwdb(8))
COPY_AS_IS_EXCLUDE+=( /etc/udev/hwdb.d /etc/udev/rules.d/*.rules /lib/udev/hwdb.d )
COPY_AS_IS_EXCLUDE+=( /lib/udev/{hwdb.d,cdrom_id,iphone*,ipod*,mtp*,snap*,udev-*-printer,v4l_id} )
COPY_AS_IS_EXCLUDE+=( /lib/udev/rules.d/*-{libgpod,libmtp,libsane,libwacom,nvidia,snap*,usb-media-players}.rules )
# disk encryption
COPY_AS_IS_EXCLUDE+=( /lib/systemd/systemd-{cryptsetup,logind,networkd*,resolved} )
# SSL
COPY_AS_IS_EXCLUDE+=( /etc/pki /etc/ssl /usr/lib/ssl /usr/share/ca-certificates)
# ReaR
COPY_AS_IS_EXCLUDE+=( "$REAR_DIR_PREFIX" )

local progs_to_exclude=()
# networking
progs_to_exclude+=( arping curl dhclient dhclient-script ethtool ifconfig ip nameif netcat netstat nslookup route rsync scp sftp ssh strace tar traceroute vi )
# file system tools
progs_to_exclude+=( btrfs cfdisk fdisk fsck 'fsck\..*' gdisk mkfs 'mkfs\..*' parted sfdisk tune2fs '.*fsck' )
# others
progs_to_exclude+=( cpio cryptsetup grub 'grub-.*' gzip rear )

Log "Before exclusion: PROGS=(${PROGS[*]})"
PROGS=( $(printf '%s\n' "${PROGS[@]}" | sed -r '/^('"$(printf '%s|' "${progs_to_exclude[@]}")"')$/d') )
Log "After exclusion: PROGS=(${PROGS[*]})"

Log "Before exclusion: REQUIRED_PROGS=(${REQUIRED_PROGS[*]})"
REQUIRED_PROGS=( $(printf '%s\n' "${REQUIRED_PROGS[@]}" | sed -r '/^('"$(printf '%s|' "${progs_to_exclude[@]}")"')$/d') )
Log "After exclusion: REQUIRED_PROGS=(${REQUIRED_PROGS[*]})"
