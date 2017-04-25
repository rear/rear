
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# If the files of the used bootloader change then we should trigger a new savelayout or mkrescue.
# The layout/save/default/445_guess_bootloader.sh script created $VAR_DIR/recovery/bootloader file.
# An artificial bash array is used so that the first array element $used_bootloader is the used bootloader:
used_bootloader=( $( cat $VAR_DIR/recovery/bootloader ) )

case $used_bootloader in
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
        # PPC arch bootloader can be :
        #  - LILO : SLES < 12
        #  - YABOOT : RHEL < 7
        #  - GRUB2 : SLES >= 12, RHEL >= 7, Ubuntu and other new Linux on POWER distro.
        CHECK_CONFIG_FILES=( ${CHECK_CONFIG_FILES[@]} /etc/lilo.conf /etc/yaboot.conf /etc/grub.cfg /etc/grub2.cfg /boot/grub2/grub2.cfg /boot/grub/grub.cfg)
        ;;
    (*)
        BugError "Unknown bootloader ($used_bootloader) - ask for sponsoring to get this fixed"
        ;;
esac
