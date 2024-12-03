#
# GRUB2 has much more commands than the legacy grub command, including modules

# cf. https://github.com/rear/rear/issues/2137
# s390 zlinux does not use grub 
# *********************************************************************************
# **** please review and recommend a better way to handle ****
# NEED TO TEST SLES - sles will probably need to use all of the grub tools below
# *********************************************************************************
[ "$ARCH" == "Linux-s390"  ] && return 0

# It is safe to assume that we are using GRUB and try to add these files to the rescue image
# even if the assumption is wrong.
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
         grubby               grub2-editenv )

# Added /etc/tuned/* to the list as /etc/tuned/bootcmdline is read by grub2-mkconfig, but was missing on
# a rescue image made on RHEL - more details in #1462
COPY_AS_IS+=( /etc/default/grub /etc/grub.d/* /etc/grub*.cfg /boot/grub*
              /usr/lib/grub* /usr/share/grub* /etc/tuned/* )

