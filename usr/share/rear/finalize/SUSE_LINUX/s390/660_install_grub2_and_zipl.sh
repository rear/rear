#
# finalize/Linux-s390/660_install_grub2_and_zipl.sh
#
# This script is iderived from finalize/Linux-i386/660_install_grub2.sh
#
# The generic way how to install the bootloader on s390 on SLES
# when one is not "inside" the system
# but "outside" like in the ReaR recovery system or in a rescue system is
# to install GRUB2 from within the target system environment via 'chroot'
# basically via commands like the following:
#
#   mount --bind /proc /mnt/local/proc
#   mount --bind /sys /mnt/local/sys
#   mount --bind /dev /mnt/local/dev
#   chroot /mnt/local /sbin/update-bootloader --reinit
#
# where "update-bootloader --reinit" does all what is needed for the
# special bootloader setup on s390 on SLES.
# On SLES12 and SLES15 booting IBM Z basically works this way:
#   Initially zipl loads a kernel and
#   that kernel runs GRUB2 and
#   GRUB2 loads the actual kernel and does a kexec
# cf. https://github.com/rear/rear/issues/2137#issuecomment-490420041
# and https://www.ibm.com/support/knowledgecenter/en/linuxonibm/com.ibm.linux.z.lhdd/lhdd_c_ipl_vs_boot.html
#
# This script does not error out because at this late state of "rear recover"
# (i.e. after the backup was restored) I <jsmeix@suse.de> consider it too hard
# to abort "rear recover" when it failed to install GRUB2 because in this case
# the user gets an explicit WARNING via finalize/default/890_finish_checks.sh
# so that after "rear recover" finished he can manually install the bootloader
# as appropriate for his particular system.

# Skip if another bootloader was already installed:
# In this case NOBOOTLOADER is not true,
# cf. finalize/default/050_prepare_checks.sh
is_true $NOBOOTLOADER || return 0

# Only for GRUB2.
# GRUB Legacy is not supported for this special bootloader setup on s390 on SLES12 and later.
# GRUB2 is detected by testing for grub-probe or grub2-probe which does not exist in GRUB Legacy.
# If neither grub-probe nor grub2-probe is there assume GRUB2 is not there:
type -p grub-probe || type -p grub2-probe || return 0

LogPrint "Installing GRUB2 boot loader plus ZIPL..."

chroot $TARGET_FS_ROOT /bin/bash --login -c "update-bootloader --reinit" && NOBOOTLOADER=''

is_true $NOBOOTLOADER || return 0
LogPrintError "Failed to install GRUB2 plus ZIPL - you may have to manually install it"
return 1

