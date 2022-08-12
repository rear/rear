
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# If the files of the used bootloader change then we should trigger a new savelayout or mkrescue.
# The layout/save/default/445_guess_bootloader.sh script created $VAR_DIR/recovery/bootloader file.
# An artificial bash array is used so that the first array element $used_bootloader is the used bootloader:
used_bootloader=( $( cat $VAR_DIR/recovery/bootloader ) )

# No quoting of the elements that are appended to the CHECK_CONFIG_FILES array together with
# the bash globbing characters like '*' or the [] around the first letter make sure
# that with 'shopt -s nullglob' files that do not exist will not appear
# so nonexistent files are not appended to CHECK_CONFIG_FILES
# cf. https://github.com/rear/rear/pull/2796#issuecomment-1117171070
case $used_bootloader in
    (EFI|GRUB2-EFI)
        CHECK_CONFIG_FILES+=( /boot/efi/EFI/*/grub*.cfg )
        ;;
    (GRUB|GRUB2)
        CHECK_CONFIG_FILES+=( /[e]tc/grub*.cfg /[b]oot/*/grub*.cfg )
        ;;
    (LILO)
        CHECK_CONFIG_FILES+=( /[e]tc/lilo.conf )
        ;;
    (ELILO)
        CHECK_CONFIG_FILES+=( /[e]tc/elilo.conf )
        ;;
    (PPC)
        # PPC arch bootloader can be :
        #  - LILO : SLES < 12
        #  - YABOOT : RHEL < 7
        #  - GRUB2 : SLES >= 12, RHEL >= 7, Ubuntu and other new Linux on POWER distro.
        CHECK_CONFIG_FILES+=( /[e]tc/lilo.conf /[e]tc/yaboot.conf /[e]tc/grub*.cfg /[b]oot/*/grub*.cfg )
        ;;
    (ARM|ARM-ALLWINNER)
        CHECK_CONFIG_FILES+=( /[b]oot/boot.scr )
        ;;
    (ZIPL)
        # cf. https://github.com/rear/rear/issues/2137
        # s390 - for rhel, ubuntu zipl config must be exist for restore.  sles > 11 does not use zipl directly
        CHECK_CONFIG_FILES+=( /[e]tc/zipl.conf )
        ;;
    (*)
        BugError "Unknown bootloader ($used_bootloader) - ask for sponsoring to get this fixed"
        ;;
esac
