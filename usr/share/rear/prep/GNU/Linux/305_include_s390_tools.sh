#
#  s390 zIPL boot loader and grubby for configuring boot loader`

test -d $VAR_DIR/recovery || mkdir -p $VAR_DIR/recovery

# Because usr/sbin/rear sets 'shopt -s nullglob' the 'echo -n' command
# outputs nothing if nothing matches the bash globbing pattern '/boot/grub*'
local bootdir="$( echo -n /boot/ )"
test -d "$bootdir" || $bootdir='/boot/'

# Check if we're using grub or grub2 before doing something.
if has_binary findmnt ; then
    echo 'run findmnt'
    findmnt -no SOURCE --target $bootdir >$VAR_DIR/recovery/bootdisk 2>/dev/null || return 0
fi

# Missing programs in the PROGS array are ignored:
PROGS=( "${PROGS[@]}" zipl grubby )

COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/zipl.conf )


