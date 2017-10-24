# GRUB2 has much more commands then the legacy grub command, including modules
# check if we're using grub2 before doing something...
[[ ! -d $VAR_DIR/recovery ]] && mkdir -p $VAR_DIR/recovery

# FIXME: Because usr/sbin/rear sets 'shopt -s nullglob' the 'ls' command will list all files
# in the current working directory if nothing matches the bash globbing pattern '/boot/grub*'
# which results '.' in 'grubdir' (the plain 'ls -d' output in the current working directory):
grubdir=$( ls -d /boot/grub* )
[[ ! -d $grubdir ]] && grubdir=/boot/grub # a safe choice

if has_binary grub-probe ; then
    grub-probe -t device $grubdir >$VAR_DIR/recovery/bootdisk 2>/dev/null || return 0
elif has_binary grub2-probe ; then
    grub2-probe -t device $grubdir >$VAR_DIR/recovery/bootdisk 2>/dev/null || return 0
fi

PROGS=( "${PROGS[@]}"
grub-install grub-mkdevicemap grub-probe grub-set-default grub-mkconfig grub-reboot grub-setup grub-mkimage grub-mkrelpath grub-mkpasswd-pbkdf2
grub2-install grub2-mkdevicemap grub2-probe grub2-set-default grub2-mkconfig grub2-reboot grub2-setup grub2-mkimage grub2-mkrelpath grub2-mkpasswd-pbkdf2
grub-bios-setup grub2-bios-setup
)

COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/default/grub /etc/grub.d/* /etc/grub*.cfg /boot/grub* /usr/lib/grub* /usr/share/grub* )
