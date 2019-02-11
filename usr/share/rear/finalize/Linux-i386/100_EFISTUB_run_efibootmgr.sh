# This script should be triggered BEFORE any other boot loader installation scripts
# in this directory. If EFI_STUB is enabled, we will automatically set
# NOBOOTLOADER variable empty to avoid other boot loader installation attempts,
# which will most probably fail (due missing binaries on original system).
# If creation process of boot entry later fails, we will just print information
# message to user to create boot entry manually, because ending restore process
# with error in such late stage is not desirable.

is_true $EFI_STUB || return 0
NOBOOTLOADER=''

local info_file="/var/lib/rear/layout/config/EFI_STUB_info.txt"

# Kernel file will be on first line of info_file
KERNEL_FILE=$(cat $info_file | sed '1!d')
TARGET_FS_ROOT_KERNEL_FILE=${TARGET_FS_ROOT}${KERNEL_FILE}

# Basically mount point holding Linux kernel.
esp_mountpoint=$( df -P "${TARGET_FS_ROOT_KERNEL_FILE}" | tail -1 | awk '{print $6}' )

loader=${TARGET_FS_ROOT_KERNEL_FILE/#"${esp_mountpoint}/"}

BootEfiDev="$( mount | grep "$esp_mountpoint" | awk '{print $1}' )"
# /dev/sda1 or /dev/mapper/vol34_part2 or /dev/mapper/mpath99p4
Dev=$( get_device_name $BootEfiDev )
# 1 (must anyway be a low nr <9)
ParNr=$( get_partition_number $Dev )
# /dev/sda or /dev/mapper/vol34_part or /dev/mapper/mpath99p
Disk=$( echo ${Dev%$ParNr} )

# Get UUID of root (/) file system
root_uuid=$(mount | grep " on $TARGET_FS_ROOT " | awk '{print $1}' | \
xargs blkid -s UUID -o value)

# we have 'mapper' in devname
if [[ ${Dev/mapper//} != $Dev ]] ; then
    # we only expect mpath_partX  or mpathpX or mpath-partX
    case $Disk in
        (*p)     Disk=${Disk%p} ;;
        (*-part) Disk=${Disk%-part} ;;
        (*_part) Disk=${Disk%_part} ;;
        (*)      Log "Unsupported kpartx partition delimiter for $Dev"
    esac
fi

# We might have value provided by user using local.conf or site.conf.
# Auto detection will be used only if EFI_STUB_EFIBOOTMGR_ARGS is empty.
if [[ -z $EFI_STUB_EFIBOOTMGR_ARGS ]]; then
    # Load arguments for efibootmgr and remove all occurrences of string "root="
    # from  info_file. We will set root= to be PARTUUID of mount point
    # holding Linux kernel, later in code.
    # root=parameter can't be reused because it don't need to match on restored system.
    # (especially if UUID or PARTUUID was used).
    # If user don't wish to use auto detected settings, he might set his own arguments
    # in EFI_STUB_EFIBOOTMGR_ARGS.
    Log "EFI_STUB: Will use auto detected UEFI boot arguments"
    EFI_STUB_EFIBOOTMGR_ARGS=$(cat ${info_file} | sed '2!d' | sed 's/root=[^[:space:]]\+//g')
    EFI_STUB_EFIBOOTMGR_ARGS+=" root=UUID=$root_uuid"
else
    Log "EFI_STUB: Using user specified UEFI boot arguments"
fi

# Using variable to be able to log and execute same command.
local efibootmgr_command="efibootmgr --create --disk ${Disk} --part ${ParNr} \
--label ${OS_VENDOR} --loader "$loader" \
--unicode \"$EFI_STUB_EFIBOOTMGR_ARGS\""

Log "EFI_STUB: Creating boot entry"
Log "EFI_STUB: Running: $efibootmgr_command"

# Running with eval to avoid overcomplicated escaping of quotes and other stuff...
# If $efibootmgr_command was executed without eval, it was somehow strangely interpreted,
# and shown in bash debug mode something like (notice the single quotes after --unicode):
# + efibootmgr <skipped_options> --unicode '"arg1' arg2 'root=PARTUUID=my_uuid1234"'
# This resulted to wrongly created boot entry which looked something like this:
# (notice ".a.r..a.r" should actually be "a.r.g.1. .a.r.g.2")
# + Boot0004* <skipped_options> ".a.r..a.r...r.o.o.t.=.P.A.R.T.U.U.I.D.=.m.y._.u.u.i.d.1.2.3.4."

eval $efibootmgr_command

if [[ $? -eq 0 ]]; then
    Log "Successfully created boot entry"
else
    LogPrint "Failed to create boot entry using command $efibootmgr_command"
    LogPrint "Your system might be unbootable, consider to create your boot entry manually."
fi
