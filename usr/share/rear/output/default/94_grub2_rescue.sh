
# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

# Add the rescue kernel and initrd to the local GRUB 2 bootloader.

# Only do it when explicitly enabled:
is_true "$GRUB_RESCUE" || return

# Only run this script when GRUB 2 is there
# (grub-probe or grub2-probe only exist in GRUB 2)
# in particular do not run this script when GRUB Legacy is used
# (for GRUB Legacy output/default/94_grub_rescue.sh is run):
type -p grub-probe >&2 || type -p grub2-probe >&2 || { LogPrint "Skipping GRUB_RESCUE setup for GRUB 2 (no GRUB 2 found)." ; return ; }

# Now GRUB_RESCUE is explicitly wanted and this script is the right one to set it up.
LogPrint "Setting up GRUB_RESCUE: Adding Relax-and-Recover rescue system to the local GRUB 2 configuration."
test "unrestricted" = "$GRUB_RESCUE_USER" && LogPrint "Anyone can boot that and replace the current system via 'rear recover'."
# Now error out whenever it cannot setup the GRUB_RESCUE functionality.

# Ensure that kernel and initrd are there:
test -r "$KERNEL_FILE" || Error "Cannot setup GRUB_RESCUE: Cannot read kernel file '$KERNEL_FILE'."
local initrd_file=$TMP_DIR/initrd.cgz
test -r $initrd_file || Error "Cannot setup GRUB_RESCUE: Cannot read initrd '$initrd_file'."

# Esure there is sufficient disk space in /boot for the local Relax-and-Recover rescue system:
function total_filesize {
    stat --format '%s' $@ | awk 'BEGIN { t=0 } { t+=$1 } END { print t }'
}
local boot_dir="/boot"
local boot_kernel_file="$boot_dir/rear-kernel"
local boot_initrd_file="$boot_dir/rear-initrd.cgz"
local available_space=$( df -Pkl $boot_dir | awk 'END { print $4 * 1024 }' )
local used_space=$( total_filesize $boot_kernel_file $boot_initrd_file )
local required_space=$( total_filesize $KERNEL_FILE $initrd_file )
if (( available_space + used_space < required_space )) ; then
    required_MiB=$(( required_space / 1024 / 1024 ))
    available_MiB=$(( ( available_space + used_space ) / 1024 / 1024 ))
    Error "Cannot setup GRUB_RESCUE: Not enough disk space in $boot_dir for Relax-and-Recover rescue system. Required: $required_MiB MiB. Available: $available_MiB MiB."
fi

# Ensure a GRUB2 configuration file is found:
local grub_conf=""
if is_true $USING_UEFI_BOOTLOADER ; then
    # set to 1 means using UEFI
    grub_conf="$( dirname $UEFI_BOOTLOADER )/grub.cfg"
elif has_binary grub2-probe ; then
    grub_conf=$( readlink -f $boot_dir/grub2/grub.cfg )
else
    grub_conf=$( readlink -f $boot_dir/grub/grub.cfg )
fi
test -w "$grub_conf" || Error "Cannot setup GRUB_RESCUE: GRUB 2 configuration '$grub_conf' cannot be modified."

# Report no longer supported GRUB 2 superuser setup if GRUB_SUPERUSER is non-empty
# (be prepared for 'set -u' by specifying an empty fallback value if GRUB_SUPERUSER is not set):
test ${GRUB_SUPERUSER:-} && LogPrint "Skipping GRUB 2 superuser setup: GRUB_SUPERUSER is no longer supported (see default.conf)."
# Report no longer supported GRUB 2 password setup if GRUB_RESCUE_PASSWORD is non-empty
# (be prepared for 'set -u' by specifying an empty fallback value if GRUB_RESCUE_PASSWORD is not set):
test ${GRUB_RESCUE_PASSWORD:-} && LogPrint "Skipping GRUB 2 password setup: GRUB_RESCUE_PASSWORD is no longer supported (see default.conf)."
# It is no error when GRUB_SUPERUSER and/or GRUB_RESCUE_PASSWORD are non-empty
# because it should work reasonably backward compatible, see default.conf

# A simple check if a GRUB_RESCUE_USER exists in the usual GRUB2 users file /etc/grub.d/01_users
# but this check is unreliable because the GRUB2 users filename could be anything else
# so that it only notifies without interpretation and does not error out if the check fails.
# On the other hand when /etc/grub.d/01_users exists then we might even assume that
# this one is the only GRUB2 users file and error out if GRUB_RESCUE_USER is not therein?
local supposed_grub_users_file="/etc/grub.d/01_users"
if test -r $supposed_grub_users_file -a "$GRUB_RESCUE_USER" -a "unrestricted" != "$GRUB_RESCUE_USER" ; then
    grep -q "$GRUB_RESCUE_USER" $supposed_grub_users_file || LogPrint "GRUB_RESCUE_USER '$GRUB_RESCUE_USER' not found in $supposed_grub_users_file - is that okay?"
fi

# Finding UUID of filesystem containing boot_dir (i.e. /boot)
grub_boot_uuid=$( df $boot_dir | awk 'END {print $1}' | xargs blkid -s UUID -o value )

# Stop if grub_boot_uuid is not a valid UUID
blkid -U $grub_boot_uuid > /dev/null 2>&1 || Error "$grub_boot_uuid is not a valid UUID"

# Creating Relax-and-Recover grub menu entry:
local grub_rear_menu_entry_file="/etc/grub.d/45_rear"
  ( echo "#!/bin/bash"
    echo "cat << EOF"
  ) > $grub_rear_menu_entry_file
if test "$GRUB_RESCUE_USER" ; then
    if test "unrestricted" = "$GRUB_RESCUE_USER" ; then
        echo "menuentry 'Relax-and-Recover' --class os --unrestricted {" >> $grub_rear_menu_entry_file
    else
        echo "menuentry 'Relax-and-Recover' --class os --users $GRUB_RESCUE_USER {" >> $grub_rear_menu_entry_file
    fi
else
    echo "menuentry 'Relax-and-Recover' --class os {" >> $grub_rear_menu_entry_file
fi
 (  echo "          search --no-floppy --fs-uuid --set=root $grub_boot_uuid"
    echo "          echo 'Loading kernel $boot_kernel_file ...'"
    echo "          linux  $boot_kernel_file $KERNEL_CMDLINE"
    echo "          echo 'Loading initrd $boot_initrd_file (may take a while) ...'"
    echo "          initrd $boot_initrd_file"
    echo "}"
    echo "EOF"
  ) >> $grub_rear_menu_entry_file
chmod 755 $grub_rear_menu_entry_file

# Generate a GRUB 2 configuration file:
local generated_grub_conf="$TMP_DIR/grub.cfg"
if [[ $( type -f grub2-mkconfig ) ]] ; then
    grub2-mkconfig -o $generated_grub_conf || Error "Failed to generate GRUB 2 configuration file (using grub2-mkconfig)."
else
    grub-mkconfig -o $generated_grub_conf || Error "Failed to generate GRUB 2 configuration file (using grub-mkconfig)."
fi
test -s $generated_grub_conf || BugError "Generated empty GRUB 2 configuration file '$generated_grub_conf'."

# Modifying local GRUB 2 configuration if it was actually changed:
if ! diff -u $grub_conf $generated_grub_conf >&2 ; then
    LogPrint "Modifying local GRUB 2 configuration."
    cp -af $v $grub_conf $grub_conf.old >&2
    cat $generated_grub_conf >$grub_conf
fi

# Provide the kernel as boot_kernel_file (i.e. /boot/rear-kernel):
if [[ $( stat -L -c '%d' $KERNEL_FILE ) == $( stat -L -c '%d' $boot_dir/ ) ]] ; then
    # Hardlink file, if possible:
    cp -pLlf $v $KERNEL_FILE $boot_kernel_file >&2
elif [[ $( stat -L -c '%s %Y' $KERNEL_FILE ) == $( stat -L -c '%s %Y' $boot_kernel_file ) ]] ; then
    # If an already existing boot_kernel_file has exact same size and modification time
    # as the current KERNEL_FILE, assume both are the same and do nothing:
    :
else
    # In all other cases, replace boot_kernel_file with the current KERNEL_FILE:
    cp -pLf $v $KERNEL_FILE $boot_kernel_file >&2
fi
BugIfError "Unable to copy '$KERNEL_FILE' to '$boot_kernel_file'."

# Provide the rear recovery system in initrd_file (i.e. TMP_DIR/initrd.cgz) as boot_initrd_file (i.e. /boot/rear-initrd.cgz):
cp -af $v $initrd_file $boot_initrd_file >&2 || BugError "Unable to copy '$initrd_file' to '$boot_initrd_file'."

LogPrint "Finished GRUB_RESCUE setup: Added 'Relax-and-Recover' GRUB 2 menu entry."

