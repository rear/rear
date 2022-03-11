# 940_grub2_rescue.sh
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# Either add the rescue kernel and initrd to the local GRUB 2 bootloader in case of BIOS
# or don't modify grub.cfg but create a separate UEFI boot entry in case of UEFI
# cf. https://github.com/rear/rear/pull/954

# With EFI_STUB enabled there will be no Grub entry.
is_true "$EFI_STUB" && return 0

# Only do it when explicitly enabled:
is_true "$GRUB_RESCUE" || return 0

# Only run this script when GRUB 2 is there
# (grub-probe or grub2-probe only exist in GRUB 2)
# in particular do not run this script when GRUB Legacy is used
# (for GRUB Legacy output/default/940_grub_rescue.sh is run):
if [[ ! $( type -p grub-probe ) && ! $( type -p grub2-probe ) ]] ; then
    Log "Skipping GRUB_RESCUE setup for GRUB 2 (no GRUB 2 found)"
    return
fi

# Now GRUB_RESCUE is explicitly wanted and this script is the right one to set it up.
local grub_rear_menu_entry_name="Relax-and-Recover"
# Refer to the "UEFI 'Relax-and-Recover' boot entry motivation" explanation below:
if is_true $USING_UEFI_BOOTLOADER ; then
    LogPrint "Setting up GRUB_RESCUE: Adding $grub_rear_menu_entry_name rescue system to the local UEFI boot manager"
    LogPrint "Anyone who can select UEFI boot entries can boot it and replace the current system via 'rear recover'"
else
    LogPrint "Setting up GRUB_RESCUE: Adding $grub_rear_menu_entry_name rescue system to the local GRUB 2 configuration"
    test "unrestricted" = "$GRUB_RESCUE_USER" && LogPrint "Anyone can boot it and replace the current system via 'rear recover'"
fi
# Now error out whenever it cannot setup the GRUB_RESCUE functionality.

# We don't need to do grub(2)-probe all the time
# adding $grub_num to whatever grub thingy should do the trick:
local grub_num=""
type -p grub2-probe && grub_num="2"

# Ensure that kernel and initrd are there:
test -r "$KERNEL_FILE" || Error "Cannot setup GRUB_RESCUE: Cannot read kernel file '$KERNEL_FILE'"
local initrd_file=$TMP_DIR/$REAR_INITRD_FILENAME
test -r $initrd_file || Error "Cannot setup GRUB_RESCUE: Cannot read initrd '$initrd_file'"

# Some commonly needed values:
local boot_dir="/boot"
local boot_kernel_name="rear-kernel"
local boot_initrd_name="rear-$REAR_INITRD_FILENAME"
local boot_kernel_file="$boot_dir/$boot_kernel_name"
local boot_initrd_file="$boot_dir/$boot_initrd_name"
local grub_config_dir="$boot_dir/grub${grub_num}"

# Esure there is sufficient disk space available in /boot for the local Relax-and-Recover rescue system:
function total_filesize {
    stat --format '%s' "$@" 2>/dev/null | awk 'BEGIN { t=0 } { t+=$1 } END { print t }'
}
# Free space in /boot:
local free_space=$( df -Pkl $boot_dir | awk 'END { print $4 * 1024 }' )
# Used space by an already existing Relax-and-Recover rescue system in /boot:
local already_used_space=$( total_filesize $boot_kernel_file $boot_initrd_file )
# Available space is the free space plus what an already existing Relax-and-Recover rescue system uses
# because an already existing Relax-and-Recover rescue system would be overwritten:
local available_space=$(( free_space + already_used_space ))
# Required space for the new Relax-and-Recover rescue system:
local required_space=$( total_filesize $KERNEL_FILE $initrd_file )
if (( available_space < required_space )) ; then
    required_MiB=$(( required_space / 1024 / 1024 ))
    available_MiB=$(( available_space / 1024 / 1024 ))
    Error "Cannot setup GRUB_RESCUE: Not enough disk space in $boot_dir for $grub_rear_menu_entry_name rescue system (required: $required_MiB MiB, available: $available_MiB MiB)"
fi

# UEFI 'Relax-and-Recover' boot entry motivation
# (cf. https://github.com/rear/rear/pull/954):
#
# If UEFI boot is in use, we will not modify grub.cfg, but setup 'Relax-and-Recover' entry in UEFI boot menu instead.
# This looks to be simplest and safest approach since finding out what mechanisms were used to boot OS in UEFI mode,
# looks to be near to impossible.
# One could argue that efibootmgr/efivars can tell you, however this entry is not mandatory and OS could be booted
# using default values or startup.nsh.
# Once UEFI loads Grub2 hell breaks loose, as Grub2 can load whatever arbitrary configuration file anywhere on the system
# or configuration file can be even embedded in bootx64.efi (and friends) as file or memdisk.
# Unfortunately there seems to be no reliable way how to track this back.
#
# Once 'Relax-and-Recover' entry in UEFI boot menu is created, user can choose to boot it from OS at next boot:
# # efibootmgr
#
# BootCurrent: 0001
# BootOrder: 0000,0001,0002,0003,0004
# Boot0000* EFI DVD/CDROM
# Boot0001* EFI Hard Drive
# Boot0002* EFI Hard Drive 1
# Boot0003* EFI Internal Shell
# Boot0004* Relax-and-Recover
#
# # /usr/sbin/efibootmgr --bootnext 4
# At next boot 'Relax-and-Recover' rescue image from /boot will be loaded.
#
# To remove 'Relax-and-Recover' UEFI boot entry:
#
# # efibootmgr -B -b 4
#
# 'Relax-and-Recover' entry can be of course selected during POST boot as well.

if ! is_true $USING_UEFI_BOOTLOADER ; then
    # Ensure a GRUB 2 configuration file is found:
    local grub_conf=$( readlink -f $grub_config_dir/grub.cfg )
    test -w "$grub_conf" || Error "Cannot setup GRUB_RESCUE: GRUB 2 configuration '$grub_conf' cannot be modified"

    # Report no longer supported GRUB 2 superuser setup if GRUB_SUPERUSER is non-empty
    # (be prepared for 'set -u' by specifying an empty fallback value if GRUB_SUPERUSER is not set):
    test ${GRUB_SUPERUSER:-} && LogPrint "Skipping GRUB 2 superuser setup: GRUB_SUPERUSER is no longer supported (see default.conf)"
    # Report no longer supported GRUB 2 password setup if GRUB_RESCUE_PASSWORD is non-empty
    # (be prepared for 'set -u' by specifying an empty fallback value if GRUB_RESCUE_PASSWORD is not set):
    test ${GRUB_RESCUE_PASSWORD:-} && LogPrint "Skipping GRUB 2 password setup: GRUB_RESCUE_PASSWORD is no longer supported (see default.conf)"
    # It is no error when GRUB_SUPERUSER and/or GRUB_RESCUE_PASSWORD are non-empty
    # because it should work reasonably backward compatible, see default.conf

    # A simple check if a GRUB_RESCUE_USER exists in the usual GRUB 2 users file /etc/grub.d/01_users
    # but this check is unreliable because the GRUB 2 users filename could be anything else
    # so that it only notifies without interpretation and does not error out if the check fails.
    # On the other hand when /etc/grub.d/01_users exists then we might even assume that
    # this one is the only GRUB 2 users file and error out if GRUB_RESCUE_USER is not therein?
    local supposed_grub_users_file="/etc/grub.d/01_users"
    if test -r $supposed_grub_users_file -a "$GRUB_RESCUE_USER" -a "unrestricted" != "$GRUB_RESCUE_USER" ; then
        grep -q "$GRUB_RESCUE_USER" $supposed_grub_users_file || LogPrint "GRUB_RESCUE_USER '$GRUB_RESCUE_USER' not found in $supposed_grub_users_file - is that okay?"
    fi
fi

# Finding UUID of filesystem containing boot_dir (i.e. /boot)
grub_boot_uuid=$( df $boot_dir | awk 'END {print $1}' | xargs blkid -s UUID -o value )

# Stop if grub_boot_uuid is not a valid UUID
blkid -U $grub_boot_uuid > /dev/null 2>&1 || Error "grub_boot_uuid '$grub_boot_uuid' is not a valid UUID"

# Creating Relax-and-Recover GRUB 2 menu entry:
local grub_rear_menu_entry_file="/etc/grub.d/45_rear"
local grub_boot_dir=$boot_dir
if mountpoint -q $boot_dir ; then
    # When /boot is a mountpoint
    # (i.e. a filesystem on a partition /dev/sdaN is mounted at /boot)
    # then GRUB uses the filesystem on /dev/sdaN directly
    # and in that filesystem there is no such thing as /boot
    # so that for GRUB the files are in the root of that filesystem:
    grub_boot_dir=""
fi

# Refer to the "UEFI 'Relax-and-Recover' boot entry motivation" explanation above:
if is_true $USING_UEFI_BOOTLOADER ; then
    # SLES12 SP1 throw kernel panic if root= variable was not set
    # probably a bug, as I was able to boot with value set to root=anything
    root_uuid=$( get_root_disk_UUID )
    test $root_uuid || LogPrintError "root_uuid '$root_uuid' empty or more than one word"

    # Create configuration file for 'Relax-and-Recover' UEFI boot entry.
    # This file will not interact with existing Grub2 configuration in any way.
    # Regarding "insmod" of GRUB2 modules see what the create_grub2_cfg function does
    # cf. https://github.com/rear/rear/pull/2609#issuecomment-831883795
    (   echo "set btrfs_relative_path=y"
        echo "insmod all_video"
        echo ""
        echo "set gfxpayload=keep"
        echo ""
        echo "menuentry '$grub_rear_menu_entry_name' --class os {"
        echo "          search --no-floppy --fs-uuid --set=root $grub_boot_uuid"
        echo "          echo 'Loading kernel $boot_kernel_file ...'"
        echo "          linux $grub_boot_dir/$boot_kernel_name root=UUID=$root_uuid $KERNEL_CMDLINE"
        echo "          echo 'Loading initrd $boot_initrd_file (may take a while) ...'"
        echo "          initrd $grub_boot_dir/$boot_initrd_name"
        echo "}"
        echo ""
        echo "menuentry 'Boot original system' {"
        echo "          search --fs-uuid --no-floppy --set=esp $esp_disk_uuid"
        echo "          chainloader (\$esp)$esp_relative_bootloader"
        echo "}"
    ) > $grub_config_dir/rear.cfg

    # Create rear.efi at UEFI default boot directory location.
    # The build_bootx86_efi errors out if it cannot make a bootable EFI image of GRUB2:
    build_bootx86_efi $boot_dir/efi/EFI/BOOT/rear.efi $grub_config_dir/rear.cfg "$boot_dir" "$UEFI_BOOTLOADER"

    # If UEFI boot entry for 'Relax-and-Recover' does not exist, create it.
    # This will also add 'Relax-and-Recover' to boot order because if UEFI entry is not listed in BootOrder,
    # it is not visible in UEFI boot menu.
    if efibootmgr | grep -q $grub_rear_menu_entry_name ; then
        LogPrint "Skip creating new 'Relax-and-Recover' UEFI boot entry (it is already there)"
    else
        # TODO: Probably this part won't work properly in case of ESP on MD RAID.
        # When the ESP is located on MD RAID we need to determine the physical RAID components
        # and call efibootmgr on each of them, cf. https://github.com/rear/rear/pull/2608
        # This part might not go that well with drivers like HPEs cciss ...
        # However UEFI booting is present since Gen8 (AFAIK), and cciss drivers were replaced by hpsa long time ago,
        # so it looks like impossible configuration, lets wait ...
        efi_disk_part=$( grep -w /boot/efi /proc/mounts | awk '{print $1}' )
        efi_disk=$( echo $efi_disk_part | sed -e 's/[0-9]//g' )
        test $efi_disk || LogPrintError "efi_disk '$efi_disk' empty or more than one word"
        efi_part=$( echo $efi_disk_part | sed -e 's/[^0-9]//g' )
        test $efi_part || LogPrintError "efi_part '$efi_part' empty or more than one word"
        # Save current BootOrder, as during `efibootmgr -c ...' phase (creating of 'Relax-and-Recover' UEFI boot entry),
        # newly created entry will be set as primary, which is not something we don't really want
        efi_boot_order=$( efibootmgr | grep "BootOrder" | cut -d ":" -f2 )
        # efibootmgr shows e.g. "BootOrder: 0000,0001,0002,0003,0004" (see the "UEFI 'Relax-and-Recover' boot entry motivation" above)
        # so efi_boot_order becomes " 0000,0001,0002,0003,0004" (i.e. with a leading space which does not matter here and below):
        test $efi_boot_order || LogPrintError "efi_boot_order '$efi_boot_order' empty or more than one word"
        # Create 'Relax-and-Recover' UEFI boot entry:
        if ! efibootmgr -c -d $efi_disk -p $efi_part -L "$grub_rear_menu_entry_name" -l "\EFI\BOOT\rear.efi" ; then
            Error "Failed to create '$grub_rear_menu_entry_name' UEFI boot entry"
        fi
        rear_boot_id=$( efibootmgr | grep -w $grub_rear_menu_entry_name | cut -d " " -f1 | sed -e 's/[^0-9]//g' )
        test $rear_boot_id || LogPrintError "rear_boot_id '$rear_boot_id' empty or more than one word"
        # Set 'Relax-and-Recover' as last entry in UEFI boot menu:
        if ! efibootmgr -o ${efi_boot_order},${rear_boot_id} ; then
            LogPrintError "Failed to set '$grub_rear_menu_entry_name' as last entry in UEFI boot menu"
        fi
    fi
else
    # Create a GRUB 2 menu config file:
      ( echo "#!/bin/bash"
        echo "cat << EOF"
      ) > $grub_rear_menu_entry_file
    if test "$GRUB_RESCUE_USER" ; then
        if test "unrestricted" = "$GRUB_RESCUE_USER" ; then
            echo "menuentry '$grub_rear_menu_entry_name' --class os --unrestricted {" >> $grub_rear_menu_entry_file
        else
            echo "menuentry '$grub_rear_menu_entry_name' --class os --users $GRUB_RESCUE_USER {" >> $grub_rear_menu_entry_file
        fi
    else
        echo "menuentry '$grub_rear_menu_entry_name' --class os {" >> $grub_rear_menu_entry_file
    fi
      ( echo "          search --no-floppy --fs-uuid --set=root $grub_boot_uuid"
        echo "          echo 'Loading kernel $boot_kernel_file ...'"
        echo "          linux $grub_boot_dir/$boot_kernel_name $KERNEL_CMDLINE"
        echo "          echo 'Loading initrd $boot_initrd_file (may take a while) ...'"
        echo "          initrd $grub_boot_dir/$boot_initrd_name"
        echo "}"
        echo "EOF"
      ) >> $grub_rear_menu_entry_file
    chmod 755 $grub_rear_menu_entry_file

    # Generate a GRUB 2 configuration file:
    local generated_grub_conf="$TMP_DIR/grub.cfg"
    if [[ $( type -f grub2-mkconfig ) ]] ; then
        grub2-mkconfig -o $generated_grub_conf || Error "Failed to generate GRUB 2 configuration file (using grub2-mkconfig)"
    else
        grub-mkconfig -o $generated_grub_conf || Error "Failed to generate GRUB 2 configuration file (using grub-mkconfig)"
    fi
    test -s $generated_grub_conf || BugError "Generated empty GRUB 2 configuration file '$generated_grub_conf'"

    # Modifying local GRUB 2 configuration if it was actually changed:
    if ! diff -u $grub_conf $generated_grub_conf >&2 ; then
        LogPrint "Modifying local GRUB 2 configuration"
        cp -af $v $grub_conf $grub_conf.old >&2
        cat $generated_grub_conf >$grub_conf
    fi
fi

# Provide the kernel as boot_kernel_file (i.e. /boot/rear-kernel):
if [[ $( stat -L -c '%d' $KERNEL_FILE ) == $( stat -L -c '%d' $boot_dir/ ) ]] ; then
    # Hardlink file, if possible:
    cp -pLlf $v $KERNEL_FILE $boot_kernel_file || BugError "Failed to hardlink '$KERNEL_FILE' to '$boot_kernel_file'"
elif [[ $( stat -L -c '%s %Y' $KERNEL_FILE ) == $( stat -L -c '%s %Y' $boot_kernel_file ) ]] ; then
    # If an already existing boot_kernel_file has exact same size and modification time
    # as the current KERNEL_FILE, assume both are the same and do nothing:
    :
else
    # In all other cases, replace boot_kernel_file with the current KERNEL_FILE:
    cp -pLf $v $KERNEL_FILE $boot_kernel_file || BugError "Failed to copy '$KERNEL_FILE' to '$boot_kernel_file'"
fi

# Provide the ReaR recovery system in initrd_file (i.e. TMP_DIR/initrd.cgz or TMP_DIR/initrd.xz)
# as boot_initrd_file (i.e. /boot/rear-initrd.cgz or /boot/rear-initrd.xz)
# (regarding '.cgz' versus '.xz' see https://github.com/rear/rear/issues/1142)
cp -af $v $initrd_file $boot_initrd_file || BugError "Failed to copy '$initrd_file' to '$boot_initrd_file'"

if is_true $USING_UEFI_BOOTLOADER ; then
    LogPrint "Finished GRUB_RESCUE setup: Added '$grub_rear_menu_entry_name' UEFI boot manager entry"
else
    LogPrint "Finished GRUB_RESCUE setup: Added '$grub_rear_menu_entry_name' GRUB 2 menu entry"
fi
