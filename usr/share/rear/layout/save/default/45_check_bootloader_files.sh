# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

# If any of our bootloader files changes then we should trigger a new savelayout or mkrescue
# prep/default/50_guess_bootloader.sh script created $VAR_DIR/recovery/bootloader file
myBOOTloader=$( cat $VAR_DIR/recovery/bootloader )

case $myBOOTloader in
    EFI)  CHECK_CONFIG_FILES=( ${CHECK_CONFIG_FILES[@]} /boot/efi/EFI/*/grub*.cfg )
        ;;
    GRUB) CHECK_CONFIG_FILES=( ${CHECK_CONFIG_FILES[@]}  /etc/grub.cfg /etc/grub2.cfg /boot/grub2/grub2.cfg /boot/grub/grub.cfg )
        ;;
    LILO) CHECK_CONFIG_FILES=( ${CHECK_CONFIG_FILES[@]} /etc/lilo.conf )
        ;;
    ELILO) CHECK_CONFIG_FILES=( ${CHECK_CONFIG_FILES[@]} /etc/elilo.conf )
        ;;
esac
