
# Prepare some checks.

# We want to tell the user if we did not install a boot loader.
# To accomplish this we set the NOBOOTLOADER variable to a true value
# that must be unset or set to an emptly value or set to a non-true value
# (so that "is_true $NOBOOTLOADER" returns false, cf. lib/global-functions.sh)
# by all boot-loader installation scripts after successfully installing a boot loader
# (i.e. "is_true $NOBOOTLOADER || echo a boot loader is already installed"):
NOBOOTLOADER=1

# Try to read the BOOTLOADER value if /var/lib/rear/recovery/bootloader is not empty.
# Currently (February 2026) the used BOOTLOADER values (grep for '$BOOTLOADER') are:
#   GRUB  for GRUB Legacy
#   GRUB2 for GRUB 2
#   ELILO for elilo
#   LILO  for lilo
#   GRUB2-EFI for GRUB 2, EFI version
#   EFI   for any EFI bootloader, dummy value
#   ARM   for ARM devices, dummy value
#   ARM-ALLWINNER for Allwinner devices
#   ZIPL  for zIPL, on IBM Z (s390x)
#   PPC   for any bootloader in the PReP boot partition (can be LILO, YABOOT, GRUB2)
#   GRUB2-BLS for GRUB2 with BLS

local bootloader_file="$VAR_DIR/recovery/bootloader"
# The output is stored in an artificial bash array so that $BOOTLOADER is the first word:
test -s $bootloader_file && BOOTLOADER=( $( grep -v '^[[:space:]]*#' $bootloader_file ) )
