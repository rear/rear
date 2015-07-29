# 35_find_syslinux_modules.sh
# syslinux version 5 and higher moved the com32 image files to modules directories and for the moment
# there are 3 forms of these (efi32, efi64 and bios)
# Purpose here is to define the proper SYSLINUX_DIR (which was already defined to the path were isolinux.bin lives)
# Of course, only when we find a modules directory

local syslinux_modules_dir=

syslinux_modules_dir=$( find_syslinux_modules_dir menu.c32 )
[[ -n "$syslinux_modules_dir" ]] && SYSLINUX_DIR="$syslinux_modules_dir"
