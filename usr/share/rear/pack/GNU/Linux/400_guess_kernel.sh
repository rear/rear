# 400_guess_kernel.sh
#
# guess kernel if not set yet or error out, for diverse Architectures (arm, aarch64, etc.)
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

if [ ! -s "$KERNEL_FILE" ]; then
    if [ -r "/boot/vmlinuz-$KERNEL_VERSION" ]; then
        KERNEL_FILE="/boot/vmlinuz-$KERNEL_VERSION"
    elif has_binary get_kernel_version; then
        for src in /boot/* ; do
            if VER=$(get_kernel_version "$src") && test "$VER" == "$KERNEL_VERSION" ; then
                KERNEL_FILE="$src"
                break
            fi
        done
    elif [ -f /etc/redhat-release ]; then
        # GD - kernel not found under /boot - 19/May/2008
        # check under /boot/efi/efi/redhat (for Red Hat)
        [ -f "/boot/efi/efi/redhat/vmlinuz-$KERNEL_VERSION" ]
        StopIfError "Could not find a matching kernel in /boot/efi/efi/redhat !"
        KERNEL_FILE="/boot/efi/efi/redhat/vmlinuz-$KERNEL_VERSION"
    elif [ -f /etc/debian_version ]; then
        [ -f "/boot/efi/efi/debian/vmlinuz-$KERNEL_VERSION" ]
        StopIfError "Could not find a matching kernel in /boot/efi/efi/debian !"
        KERNEL_FILE="/boot/efi/efi/debian/vmlinuz-$KERNEL_VERSION"
    elif [ -f /etc/arch-release ]; then
        if [ -f "/boot/vmlinuz-linux" ] ; then
            KERNEL_FILE="/boot/vmlinuz-linux"
        elif [ -f "/boot/vmlinuz26" ] ; then
            KERNEL_FILE="/boot/vmlinuz26"
        else
            Error "Could not find Arch kernel /boot/vmlinuz[-linux|26]"
        fi
    elif [ -f /etc/gentoo-release ]; then
        if [ -f "/boot/kernel-genkernel-${REAL_MACHINE}-${KERNEL_VERSION}" ]; then
            KERNEL_FILE="/boot/kernel-genkernel-${REAL_MACHINE}-${KERNEL_VERSION}"
        elif [ -f "/boot/kernel-${KERNEL_VERSION}" ]; then
            KERNEL_FILE="/boot/kernel-${KERNEL_VERSION}"
        else
            Error "Could not find Gentoo kernel"
        fi
    else
        Error "Could not find a matching kernel in /boot !"
    fi
fi

[ -s "$KERNEL_FILE" ]
StopIfError "Could not find a suitable kernel. Maybe you have to set KERNEL_FILE [$KERNEL_FILE] ?"

if [ -L $KERNEL_FILE ]; then
    KERNEL_FILE=$(readlink -f $KERNEL_FILE)
fi

Log "Guessed kernel $KERNEL_FILE"

