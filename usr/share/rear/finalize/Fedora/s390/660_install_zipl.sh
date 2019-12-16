#
# finalize/Linux-s390/660_install_grub2_and_zipl.sh
#
# This script is iderived from finalize/Linux-i386/660_install_grub2.sh
#
# The generic way how to install the bootloader on s390 on RHEL
# when one is not "inside" the system
# but "outside" like in the ReaR recovery system or in a rescue system is
# to install zipl from within the target system environment via 'chroot'
# basically via commands like the following:
#
#   chroot /mnt/local /sbin/zipl -n
#
# where -n mean non-interactive
# special bootloader setup on s390 on RHEL.
# On RHEL booting IBM Z basically works this way:
#   The bootloader (zIPL) is IPL'd which then loads the kernel
#   the kernel then loads the initramfs and startints running the init scripts
#   zipl is boot loader
#   zipl uses /etc/zipl.conf to configure the loader
#
# cf. https://github.com/rear/rear/issues/2137#issuecomment-490420041
# and https://www.ibm.com/support/knowledgecenter/en/linuxonibm/com.ibm.linux.z.lhdd/lhdd_c_ipl_vs_boot.html
#
# from man pages:
#       +---------------------------------------------------------------+
#       | Arch           | Bootloader | Configuration File              |
#       |---------------------------------------------------------------|
#       | x86_64 [BIOS]  | grub2      | /boot/grub2/grub.cfg            |
#       |---------------------------------------------------------------|
#       | x86_64 [UEFI]  | grub2      | /boot/efi/EFI/redhat/grub.cfg   |
#       |---------------------------------------------------------------|
#       | i386           | grub2      | /boot/grub2/grub.cfg            |
#       |---------------------------------------------------------------|
#       | ia64           | elilo      | /boot/efi/EFI/redhat/elilo.conf |
#       |---------------------------------------------------------------|
#       | ppc [>=Power8] | grub2      | /boot/grub2/grub.cfg            |
#       |---------------------------------------------------------------|
#       | ppc [<=Power7] | yaboot     | /etc/yaboot.conf                |
#       |---------------------------------------------------------------|
#       | s390           | zipl       | /etc/zipl.conf                  |
#       |---------------------------------------------------------------|
#       | s390x          | zipl       | /etc/zipl.conf                  |
#       +---------------------------------------------------------------+


# This script does not error out because at this late state of "rear recover"
# (i.e. after the backup was restored) I <jsmeix@suse.de> consider it too hard
# to abort "rear recover" when it failed to install zIPL because in this case
# the user gets an explicit WARNING via finalize/default/890_finish_checks.sh
# so that after "rear recover" finished he can manually install the bootloader
# as appropriate for his particular system.

# Skip if another bootloader was already installed:
# In this case NOBOOTLOADER is not true,
# cf. finalize/default/050_prepare_checks.sh
is_true $NOBOOTLOADER || return 0

LogPrint "Installing boot loader ZIPL..."

#chroot $TARGET_FS_ROOT /bin/bash --login -c "update-bootloader --reinit" && NOBOOTLOADER=''
chroot $TARGET_FS_ROOT /sbin/zipl && NOBOOTLOADER=''

is_true $NOBOOTLOADER || return 0
LogPrintError "Failed to install ZIPL - you may have to manually install it"
return 1

