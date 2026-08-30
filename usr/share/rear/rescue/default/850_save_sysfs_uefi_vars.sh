
# Determine what to use as UEFI bootloader file (UEFI_BOOTLOADER).
# A simplified uefivars replacement.

# USING_UEFI_BOOTLOADER empty or no explicit 'true' value means NO UEFI:
is_true $USING_UEFI_BOOTLOADER || return 0

# Don't do any guess work for boot loader, we will use systemd-bootx64.efi.
is_true $EFI_STUB && return 0

local current_uefi_bootloader=""
local default_uefi_bootloader=""
local uefi_bootloader_relative=""
local distribution_uefi_bootloader=""
local uefi_bootloader_line=""
local uefi_bootloader_base_lower=""
local grub_next_to_boot_efi=""

local dummy
# Artificial 'for' clause that is run only once
for dummy in once ; do
    LogPrint "Trying to autodetect from EFI variables what to use as UEFI bootloader file..."
    # TODO: I <jsmeix@suse.de> cannot find a file named uefi-variables used elsewhere in the ReaR scripts
    # so that I wonder what the reason is why this file is stored in VAR_DIR and not in TMP_DIR?
    test -d "$VAR_DIR/recovery" || mkdir -p -m 755 $VAR_DIR/recovery
    local uefi_variables_file=$VAR_DIR/recovery/uefi-variables
    rm -f $uefi_variables_file
    local efibootmgr_output=$TMP_DIR/efibootmgr_output
    efibootmgr > "$efibootmgr_output"
    local uefi_dir=""
    local uefi_file=""
    local uefi_var=""
    local efi_data=""
    local efi_attr=""
    local boot_current=""
    local uefi_bootloader_DOS_path=""
    # Depending the directory ends on vars or efivars we need to treat it different.
    # See prep/default/320_include_uefi_env.sh how SYSFS_DIR_EFI_VARS is set:
    case "$SYSFS_DIR_EFI_VARS" in
        (/sys/firmware/efi/vars)
            # Disable SC2045: "Iterating over ls output is fragile. Use globs."
            # because SYSFS_DIR_EFI_VARS is a directory where we want to 'ls' its contents
            # shellcheck disable=SC2045
            for uefi_dir in $( ls $SYSFS_DIR_EFI_VARS ) ; do
                uefi_var=$( echo $uefi_dir | cut -d- -f 1 )
                [[ "$uefi_var" = "new_var" ]] && continue
                [[ "$uefi_var" = "del_var" ]] && continue
                efi_data="$( efibootmgr_read_var $uefi_var $efibootmgr_output )"
                [[ -z "$efi_data" ]] && efi_data="$( uefi_read_data $SYSFS_DIR_EFI_VARS/$uefi_dir/data )"
                efi_attr="$( uefi_read_attributes $SYSFS_DIR_EFI_VARS/$uefi_dir/attributes )"
                echo "$uefi_var $efi_attr: $efi_data" >> $uefi_variables_file
            done
            # Finding the correct EFI bootloader in use:
            boot_current=$( grep BootCurrent $uefi_variables_file | cut -d: -f2 | awk '{print $1}' ) # 0000
            uefi_bootloader_DOS_path=$( uefi_extract_bootloader $SYSFS_DIR_EFI_VARS/Boot${boot_current}-*/data )
            ;;
        (/sys/firmware/efi/efivars)
            # Disable SC2045: "Iterating over ls output is fragile. Use globs."
            # because SYSFS_DIR_EFI_VARS is a directory where we want to 'ls' its contents
            # shellcheck disable=SC2045
            for uefi_file in $( ls $SYSFS_DIR_EFI_VARS ) ; do
                uefi_var=$( echo $uefi_file | cut -d- -f 1 )
                efi_data="$( efibootmgr_read_var $uefi_var $efibootmgr_output )"
                [[ -z "$efi_data" ]] && efi_data="$( uefi_read_data $SYSFS_DIR_EFI_VARS/$uefi_file )"
                echo "$uefi_var $efi_attr: $efi_data" >> $uefi_variables_file
                #TODO: efi_attr how to extract??
            done
            # Finding the correct EFI bootloader in use:
            boot_current=$( grep BootCurrent $uefi_variables_file | cut -d: -f2 | awk '{print $1}' ) # 0000
            uefi_bootloader_DOS_path=$( uefi_extract_bootloader $SYSFS_DIR_EFI_VARS/Boot${boot_current}-* )
            ;;
        (*)
            LogPrint "EFI variables directory $SYSFS_DIR_EFI_VARS is neither /sys/firmware/efi/vars nor /sys/firmware/efi/efivars (ReaR supports only those)"
            LogPrint "This is expected if you try to make a UEFI boot media on a BIOS system"
            # some path guessing will be needed, leave current_uefi_bootloader empty to indicate this
            continue
            ;;
    esac
    # Replace backslashes with slashes because uefi_bootloader_DOS_path contains path in DOS format:
    current_uefi_bootloader="/boot/efi"$( echo "$uefi_bootloader_DOS_path" | sed -e 's;\\;/;g' )
    LogPrint "Detected current EFI bootloader $current_uefi_bootloader"
done

# Locate distribution-specific bootloaders provided using the fallback mechanism.
# https://github.com/rhboot/shim/blob/main/README.fallback
for find_name_pattern in "BOOT${EFI_ARCH_UPPER}.CSV" "BOOT.CSV" ; do
    while read boot_csv_filename ; do
        # iconv -t UTF-16 strips the BOM (byte order mark), with UCS-2 it would preserve it
        while read uefi_bootloader_line ; do
            uefi_bootloader_relative="$( cut -d, -f1 <<<$uefi_bootloader_line )"
        done < <(iconv -f UTF-16 < "$boot_csv_filename")
        LogPrint "Detected distribution EFI bootloader $uefi_bootloader_relative in $boot_csv_filename"
        if test -f "$(dirname "$boot_csv_filename")/$uefi_bootloader_relative" ; then
            distribution_uefi_bootloader="$(dirname "$boot_csv_filename")/$uefi_bootloader_relative"
            if [ "$current_uefi_bootloader" = "$distribution_uefi_bootloader" ] ; then
                # best guess - bootloader matches the current boot entry
                continue 2
            elif [ "$(dirname "$current_uefi_bootloader")" = "$(dirname "$boot_csv_filename")" ] ; then
                # bootloader is at least in the same directory as the current boot entry
                continue 2
            fi
            # leave distribution_uefi_bootloader set and continue searching -
            # maybe we will find a better candidate
        else
            LogPrint "Detected bootloader $(dirname "$boot_csv_filename")/$uefi_bootloader_relative does not exist"
        fi
    done < <(find /boot/efi -iname "$find_name_pattern")
done

# null SECURE_BOOT_BOOTLOADER, that is "" (empty string) means that the user does not want
# a Secure Boot bootloader. Autodetect it only when unset. The default should thus be
# SECURE_BOOT_BOOTLOADER unset, not "", to enable autodetection.
if test -f "$current_uefi_bootloader" ; then
    uefi_bootloader_base_lower="$( basename "${current_uefi_bootloader,,}" .efi )"
    if [ "$uefi_bootloader_base_lower" = "shim" ] || [ "$uefi_bootloader_base_lower" = "shim$EFI_ARCH" ] ; then
        # current UEFI bootloader name looks like the EFI shim
        # we set SECURE_BOOT_BOOTLOADER only if unset (not if null)
        SECURE_BOOT_BOOTLOADER="${SECURE_BOOT_BOOTLOADER-$current_uefi_bootloader}"
    fi
elif test -f "$distribution_uefi_bootloader" ; then
    uefi_bootloader_base_lower="$( basename "${distribution_uefi_bootloader,,}" .efi )"
    if [ "$uefi_bootloader_base_lower" = "shim" ] || [ "$uefi_bootloader_base_lower" = "shim$EFI_ARCH" ] ; then
        # distribution UEFI bootloader name looks like the EFI shim
        # we set SECURE_BOOT_BOOTLOADER only if unset (not if null)
        SECURE_BOOT_BOOTLOADER="${SECURE_BOOT_BOOTLOADER-$distribution_uefi_bootloader}"
    fi
else
    # the system may have booted via the default bootloader:
    # EFI/BOOT/BOOTX64.EFI
    default_uefi_bootloader="$( cd /boot/efi ; find . -ipath ./efi/boot/boot${EFI_ARCH}.efi | tail -1 )"
    # set default_uefi_bootloader to the full path, but only if already set
    default_uefi_bootloader="${default_uefi_bootloader:+/boot/efi/${default_uefi_bootloader#./}}"
    if test -f "$default_uefi_bootloader" ; then
        # the default bootloader may be the EFI shim, if grub*.efi exists in the same directory
        grub_next_to_boot_efi="$( find "$(dirname "$default_uefi_bootloader" )" -iname 'grub*.efi' | tail -1 )"
        if test -f "$grub_next_to_boot_efi" ; then
            # There is grub next to the default bootloader, let's assume that the default bootloader
            # is the EFI shim, if the user has not specified otherwise.
            # we set SECURE_BOOT_BOOTLOADER only if unset (not if null)
            SECURE_BOOT_BOOTLOADER="${SECURE_BOOT_BOOTLOADER-$default_uefi_bootloader}"
        fi
    fi
fi

# Finished with Secure Boot bootlaoder detection.
# If SECURE_BOOT_BOOTLOADER is empty or unset, we are quite sure that the user does not want it
# or Secure Boot bootloader it could not be found.
SECURE_BOOT_BOOTLOADER="${SECURE_BOOT_BOOTLOADER:-}"

# Artificial 'for' clause that is run only once
# to be able to 'continue' with the code after it
# as soon as an usable UEFI bootloader file is found
# (the 'for' loop is run only once so that 'continue' is the same as 'break')
# which avoids dowdy looking code with deeply nested 'if...else' conditions:
for dummy in "once" ; do
    # When the user has specified UEFI_BOOTLOADER in /etc/rear/local.conf use it if exists and is a regular file.
    # Double quotes are mandatory here because 'test -f' without any (possibly empty) argument results true:
    test -f "$UEFI_BOOTLOADER" && continue

    # Now fall back step by step to more and more complicated autodetection methods
    # until a usable UEFI bootloader file is found or error out if nothing is found.
    # Keep the user informed what kind of autodetection method is tried next:

    LogPrint "Trying to find what to use as UEFI bootloader..."
    # When UEFI_BOOTLOADER is not a regular file the user may have specified it
    # as a single string or as an array of filename globbing patterns for 'find'.
    # Because what the user has specified must have precedence over automatisms
    # this user specified 'find' must run before the other autodetections.
    # Using UEFI_BOOTLOADER as a single string or as an array works because
    # normal single string variables and arrays work reasonably compatible
    # i.e. "$VAR[@]" works for a single string variable VAR (results the string)
    # and "$ARR" works for an array variable (results the first array member) and
    # also ARR="string" works for an array variable (sets the first array member)
    # cf. https://github.com/rear/rear/pull/1212#issuecomment-283333298
    # On older systems where 'find' does not support '-iname' this does not make
    # it really worse because there 'find' just fails. I <jsmeix@suse.de> have
    # tested that on SUSE systems 'find' supports '-iname' down to SLES 10 SP4
    # cf. https://github.com/rear/rear/pull/1204#issuecomment-283045547
    for find_name_pattern in "${UEFI_BOOTLOADER[@]}" ; do
        # No need to test if find_name_pattern is empty because 'find' does not find anything with empty '-iname':
        UEFI_BOOTLOADER=$( find /boot -iname "$find_name_pattern" | tail -1 )
        # Continue with the code after the outer 'for' loop:
        test -f "$UEFI_BOOTLOADER" && continue 2
    done

    if test -f "$SECURE_BOOT_BOOTLOADER" ; then
        LogPrint "Trying to find grub*.efi in the directory of the Secure Boot bootloader $SECURE_BOOT_BOOTLOADER to be used as UEFI bootloader..."
        UEFI_BOOTLOADER="$( find "$(dirname "$SECURE_BOOT_BOOTLOADER" )" -iname 'grub*.efi' | tail -1 )"
        test -f "$UEFI_BOOTLOADER" && continue
    fi
    LogPrint "Trying to find a 'well known file' to be used as UEFI bootloader..."
    UEFI_BOOTLOADER=$( find /boot/efi -name 'grub*.efi' | tail -1 )
    test -f "$UEFI_BOOTLOADER" && continue
    # In case we have an elilo bootloader we might be lucky with next statement:
    UEFI_BOOTLOADER=$( find /boot/efi -name 'elilo.efi' | tail -1 )
    test -f "$UEFI_BOOTLOADER" && continue
    # In case we have a 64-bit systemd bootloader we might be lucky with next statement:
    UEFI_BOOTLOADER=$( find /boot/EFI -name "BOOT${EFI_ARCH_UPPER}.EFI" | tail -1 )
    test -f "$UEFI_BOOTLOADER" && continue
    # Try more generic finds in whole /boot with case insensitive filename matching.
    # On older systems where 'find' does not support '-iname' this does not make it really worse because there 'find' just fails.
    for find_name_pattern in 'grub*.efi' 'elilo.efi' "BOOT${EFI_ARCH_UPPER}.EFI" ; do
        # No need to test if find_name_pattern is empty because 'find' does not find anything with empty '-iname':
        UEFI_BOOTLOADER=$( find /boot -iname "$find_name_pattern" | tail -1 )
        # Continue with the code after the outer 'for' loop:
        test -f "$UEFI_BOOTLOADER" && continue 2
    done

    if test "$current_uefi_bootloader" ; then
        LogPrint "Using current bootloader $current_uefi_bootloader detected from EFI variables as UEFI bootloader file"
        UEFI_BOOTLOADER="$current_uefi_bootloader"
    else
        # try some path guessing now
        UEFI_BOOTLOADER=$( find /usr/lib/grub -iname "grub${EFI_ARCH}.efi" | tail -1 )
    fi

    test -f "$UEFI_BOOTLOADER" && continue

    # Error out when no usable UEFI bootloader file could be autodetected:
    Error "Cannot autodetect what to use as UEFI_BOOTLOADER, you have to manually specify it in $CONFIG_DIR/local.conf"

done

test "$UEFI_BOOTLOADER" != "$SECURE_BOOT_BOOTLOADER" || Error "UEFI_BOOTLOADER ('$UEFI_BOOTLOADER') = SECURE_BOOT_BOOTLOADER, cannot autodetect what to use as second stage bootloader"

# Show to the user what will actually be used as UEFI bootloader file:
if test -f "$SECURE_BOOT_BOOTLOADER" ; then
    LogPrint "Using '$SECURE_BOOT_BOOTLOADER' as UEFI Secure Boot bootloader file"
else
    LogPrint "Using '$UEFI_BOOTLOADER' as UEFI bootloader file (non Secure Boot)"
fi

# Save the variables we need in recover mode into the rescue.conf file:
cat - <<EOF >> "$ROOTFS_DIR/etc/rear/rescue.conf"
USING_UEFI_BOOTLOADER=$USING_UEFI_BOOTLOADER
UEFI_BOOTLOADER="$UEFI_BOOTLOADER"
SECURE_BOOT_BOOTLOADER="$SECURE_BOOT_BOOTLOADER"
EOF

