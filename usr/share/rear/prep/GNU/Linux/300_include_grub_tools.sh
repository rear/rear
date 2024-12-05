
# GRUB tools are normally not required inside the recovery system for "rear recover"
# because during "rear recover" GRUB is installed within the recreated target system
# via chroot into the recreated target system.
# There is one exception for GRUB2: grub-probe or grub2-probe
# This is required inside the recovery system because the function
# is_grub2_installed is also called during "rear recover"
# in finalize/Linux-i386/630_install_grub.sh
# and finalize/Linux-i386/660_install_grub2.sh
# And 'type -p grub-probe || type -p grub2-probe' is called during "rear recover"
# in finalize/Linux-ppc64le/660_install_grub2.sh
# and finalize/SUSE_LINUX/s390/660_install_grub2_and_zipl.sh
# Other code places that call 'has_binary grub-probe' or 'has_binary grub2-probe'
# are not run during "rear recover"
# (at least as far as I <jsmeix@suse.de> found out up to now dated 05 Dec. 2024)
# cf. https://github.com/rear/rear/pull/3354#issuecomment-2519520750

# But GRUB tools are useful in general inside the
# recovery system for a different use case which is
# using the ReaR recovery system to repair the system,
# in particular to repair GRUB on the original system
# when the original system fails to boot.

# GRUB2 has much more commands than the legacy grub command, including modules

# cf. https://github.com/rear/rear/issues/2137
# s390 zlinux does not use grub 
# *********************************************************************************
# **** please review and recommend a better way to handle ****
# NEED TO TEST SLES - sles will probably need to use all of the grub tools below
# *********************************************************************************
[ "$ARCH" == "Linux-s390"  ] && return 0

# It is safe to assume that we are using GRUB and try to add these files to the rescue image
# even if the assumption is wrong, cf. https://github.com/rear/rear/pull/3349#issuecomment-2503808679
# Missing programs in the PROGS array are ignored:
PROGS+=( grub-bios-setup      grub2-bios-setup
         grub-install         grub2-install
         grub-mkconfig        grub2-mkconfig
         grub-mkdevicemap     grub2-mkdevicemap
         grub-mkimage         grub2-mkimage
         grub-mkpasswd-pbkdf2 grub2-mkpasswd-pbkdf2
         grub-mkrelpath       grub2-mkrelpath
         grub-probe           grub2-probe
         grub-reboot          grub2-reboot
         grub-set-default     grub2-set-default
         grub-setup           grub2-setup
         grub-editenv         grub2-editenv
         grubby )

# Added /etc/tuned/* to the list as /etc/tuned/bootcmdline is read by grub2-mkconfig, but was missing on
# a rescue image made on RHEL - more details in #1462
COPY_AS_IS+=( /etc/default/grub /etc/grub.d/* /etc/grub*.cfg /boot/grub*
              /usr/lib/grub* /usr/share/grub* /etc/tuned/* )

