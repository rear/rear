# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# If any of our bootloader files changes then we should trigger a new savelayout or mkrescue
# prep/default/500_guess_bootloader.sh script created $VAR_DIR/recovery/bootloader file
myBOOTloader=$( cat $VAR_DIR/recovery/bootloader )

case $myBOOTloader in
    (EFI|GRUB2-EFI)
        CHECK_CONFIG_FILES=( ${CHECK_CONFIG_FILES[@]} /boot/efi/EFI/*/grub*.cfg )
        ;;
    (GRUB|GRUB2)
        CHECK_CONFIG_FILES=( ${CHECK_CONFIG_FILES[@]} /etc/grub.cfg /etc/grub2.cfg /boot/grub2/grub2.cfg /boot/grub/grub.cfg )
        ;;
    (LILO)
        CHECK_CONFIG_FILES=( ${CHECK_CONFIG_FILES[@]} /etc/lilo.conf )
        ;;
    (ELILO)
        CHECK_CONFIG_FILES=( ${CHECK_CONFIG_FILES[@]} /etc/elilo.conf )
        ;;
    (PPC)
        CHECK_CONFIG_FILES=( ${CHECK_CONFIG_FILES[@]} /etc/lilo.conf /etc/yaboot.conf)
        ;;
    (*)
        BugError "Unknown bootloader ($myBOOTloader) - ask for sponsoring to get this fixed"
        ;;
esac
