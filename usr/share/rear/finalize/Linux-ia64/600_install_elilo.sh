#
# ia64 uses elilo by default. There is no information stored in the system about the boot
# loader installation, so we can only guess and hope elilo is used
LogPrint "Not installing any boot loader (hoping EFI works and /boot/efi was restored)."
NOBOOTLOADER=
