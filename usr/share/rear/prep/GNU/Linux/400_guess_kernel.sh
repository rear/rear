# 400_guess_kernel.sh
#
# Guess kernel if not set yet or error out,
# for diverse Architectures (arm, aarch64, etc.)
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# When KERNEL_FILE is specified by the user use that
# (KERNEL_FILE is empty in default.conf):
if test "$KERNEL_FILE" ; then
    if test -L "$KERNEL_FILE" ; then
        # If KERNEL_FILE is a symlink, use its (final) target:
        KERNEL_FILE="$( readlink $v -e "$KERNEL_FILE" )"
        if test -s "$KERNEL_FILE" ; then
            LogPrint "Using symlink target '$KERNEL_FILE' of specified KERNEL_FILE as kernel in the recovery system"
            return
        fi
        # KERNEL_FILE is empty here because readlink results nothing when there is no symlink target: 
        Error "Specified KERNEL_FILE is a broken symbolic link"
    fi
    if test -s "$KERNEL_FILE" ; then
        LogPrint "Using specified KERNEL_FILE '$KERNEL_FILE' as kernel in the recovery system"
        return
    fi
    Error "Specified KERNEL_FILE '$KERNEL_FILE' does not exist"
fi

# Artificial 'for' clause that is run only once
# to be able to 'continue' with the code after it
# as soon as a usable kernel file is found
# (the 'for' loop is run only once so that 'continue' is the same as 'break')
# which avoids dowdy looking code with nested 'if...else' conditions
# cf. rescue/default/850_save_sysfs_uefi_vars.sh:
for dummy in "once" ; do

    # Try /boot/vmlinuz-$KERNEL_VERSION:
    KERNEL_FILE="/boot/vmlinuz-$KERNEL_VERSION"
    test -s "$KERNEL_FILE" && continue
    Log "No kernel file '$KERNEL_FILE' found"

    # Try all files in /boot if one matches KERNEL_VERSION="$( uname -r )" cf. default.conf: 
    if has_binary get_kernel_version ; then
        local kernel_version=""
        for KERNEL_FILE in $( find /boot -type f ) ; do
            # At least on openSUSE Leap 15.0 get_kernel_version outputs nothing for files that are no kernel:
            kernel_version="$( get_kernel_version "$KERNEL_FILE" )"
            # Continue with the code after the outer 'for' loop:
            test "$kernel_version" = "$KERNEL_VERSION" && continue 2
        done
        # The usually expected case is that a kernel is found in /boot that matches KERNEL_VERSION
        # so that we show to the user when the usually expected case does not hold on his system:
        LogPrint "No kernel found in /boot that matches KERNEL_VERSION '$KERNEL_VERSION'"
    else
        Log "No get_kernel_version binary, skipping searching for kernel file in /boot"
    fi

    # Slackware may have no get_kernel_version why kernel may not have been found above under /boot
    # so that possible Slackware kernel is tested individulally here:
    if test -f /etc/slackware-version ; then
        KERNEL_FILE="/boot/efi/EFI/Slackware/vmlinuz"
        test -s "$KERNEL_FILE" && continue
        Log "No Slackware kernel file '$KERNEL_FILE' found"
    fi

    # Red Hat kernel may not have been found above under /boot
    # so that /boot/efi/efi/redhat is also tried:
    if test -f /etc/redhat-release ; then
        KERNEL_FILE="/boot/efi/efi/redhat/vmlinuz-$KERNEL_VERSION"
        test -s "$KERNEL_FILE" && continue
        Log "No Red Hat kernel file '$KERNEL_FILE' found"
    fi

    # Debian kernel may not have been found above under /boot
    # so that /boot/efi/efi/debian is also tried:
    if test  -f /etc/debian_version ; then
        KERNEL_FILE="/boot/efi/efi/debian/vmlinuz-$KERNEL_VERSION"
        test -s "$KERNEL_FILE" && continue
        Log "No Debian kernel file '$KERNEL_FILE' found"
    fi

    # Arch Linux kernel may not have been found above under /boot
    # so that other files are also tried:
    if test -f /etc/arch-release ; then
        for KERNEL_FILE in /boot/vmlinuz-linux /boot/vmlinuz26 ; do
            # Continue with the code after the outer 'for' loop:
            test -s "$KERNEL_FILE" && continue 2
            Log "No Arch Linux kernel file '$KERNEL_FILE' found"
        done
    fi
    
    # Gentoo kernel may not have been found above under /boot
    # so that other files are also tried:
    if test -f /etc/gentoo-release ; then
        for KERNEL_FILE in "/boot/kernel-genkernel-$REAL_MACHINE-$KERNEL_VERSION" "/boot/kernel-$KERNEL_VERSION" ; do
            # Continue with the code after the outer 'for' loop:
            test -s "$KERNEL_FILE" && continue 2
            Log "No Gentoo kernel file '$KERNEL_FILE' found"
        done
    fi

    # Error out when no kernel was found up to here:
    Error "Cannot autodetect what to use as KERNEL_FILE, you have to manually specify it in $CONFIG_DIR/local.conf"
 
done

# If KERNEL_FILE is a symlink, use its (final) target:
test -L "$KERNEL_FILE" && KERNEL_FILE="$( readlink -e "$KERNEL_FILE" )"

# Show to the user what will actually be used as kernel in the recovery system:
LogPrint "Using '$KERNEL_FILE' as kernel in the recovery system"

