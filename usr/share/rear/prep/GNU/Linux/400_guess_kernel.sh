# 400_guess_kernel.sh
#
# Guess what to use as kernel in the recovery system if not specified or error out.
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# When KERNEL_FILE is specified by the user use that as is or error out
# cf. https://github.com/rear/rear/pull/1985#discussion_r237451729
# (KERNEL_FILE is empty in default.conf):
if test "$KERNEL_FILE" ; then
    if test -L "$KERNEL_FILE" ; then
        # If KERNEL_FILE is a symlink, use its (final) target:
        local specified_kernel="$KERNEL_FILE"
        KERNEL_FILE="$( readlink $v -e "$KERNEL_FILE" )"
        # readlink results nothing when there is no symlink target:
        test -s "$KERNEL_FILE" || Error "Specified KERNEL_FILE '$specified_kernel' is a broken symbolic link"
        LogPrint "Using symlink target '$KERNEL_FILE' of specified KERNEL_FILE '$specified_kernel' as kernel in the recovery system"
        return
    fi
    test -s "$KERNEL_FILE" || Error "Specified KERNEL_FILE '$KERNEL_FILE' does not exist"
    LogPrint "Using specified KERNEL_FILE '$KERNEL_FILE' as kernel in the recovery system"
    return
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
    # ppc64el uses uncompressed kernel
    KERNEL_FILE="/boot/vmlinux-$KERNEL_VERSION"
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

# Show to the user what will actually be used as kernel in the recovery system or error out
# cf. the code at the beginning "When KERNEL_FILE is specified by the user":
if test -L "$KERNEL_FILE" ; then
    # If KERNEL_FILE is a symlink, use its (final) target:
    local autodetected_kernel="$KERNEL_FILE"
    KERNEL_FILE="$( readlink $v -e "$KERNEL_FILE" )"
    # readlink results nothing when there is no symlink target:
    test -s "$KERNEL_FILE" || Error "Autodetected kernel '$autodetected_kernel' is a broken symbolic link"
    LogPrint "Using symlink target '$KERNEL_FILE' of autodetected kernel '$autodetected_kernel' as kernel in the recovery system"
    return
fi
# There must be a bug in the autodetection code above when a file is autodetected but does not exist:
test -s "$KERNEL_FILE" || BugError "Autodetected kernel '$KERNEL_FILE' does not exist"
LogPrint "Using autodetected kernel '$KERNEL_FILE' as kernel in the recovery system"

