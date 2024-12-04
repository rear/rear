# Configure the workflow for TCG Opal pre-boot authentication (PBA) image creation

has_binary sedutil-cli || Error "Executable sedutil-cli is missing. Cannot create a TCG Opal PBA without it."

LogPrint "Re-configuring Relax-and-Recover to create a TCG Opal pre-boot authentication (PBA) image"

# Configure kernel
KERNEL_CMDLINE+=" quiet splash systemd.volatile=yes systemd.unit=sysinit-opalpba.target $OPAL_PBA_KERNEL_CMDLINE"
USE_SERIAL_CONSOLE="$OPAL_PBA_USE_SERIAL_CONSOLE"

# Strip kernel files to a reasonable minimum
if (( ${#OPAL_PBA_FIRMWARE_FILES[@]} > 0 )); then
    # Prefer OPAL_PBA_FIRMWARE_FILES if non-empty.
    FIRMWARE_FILES=( "${OPAL_PBA_FIRMWARE_FILES[@]}" )
elif [[ -z "${FIRMWARE_FILES[*]}" ]] || is_true "$FIRMWARE_FILES"; then
    # Always override an empty or 'yes'-like setting for FIRMWARE_FILES
    # as this will make the PBA exceed its allowable size.
    FIRMWARE_FILES=( 'no' )
fi
MODULES=( 'loaded_modules' )
local exclude_modules='kvm.*|nvidia.*|vbox.*'
EXCLUDE_MODULES+=( $(lsmod | tail -n +2 | cut -d ' ' -f 1 | while read m; do modprobe -R $m; done | grep -E '^('"$exclude_modules"'$)' ) )

# Avoid any information which could hint an attacker
EXCLUDE_RUNTIME_LOGFILE='yes'
SSH_ROOT_PASSWORD=''

# Disable non-essential stuff
SSH_FILES='no'
USE_DHCLIENT='no'
USE_RESOLV_CONF='no'

# Add programs, files and libraries
if (( ${#OPAL_PBA_PROGS[@]} == 0 && ${#OPAL_PBA_COPY_AS_IS[@]} == 0)) && has_binary plymouth; then
    LogPrintError "TIP: Your system seems to include a Plymouth graphical boot animation. You can achieve a nicer user"
    LogPrintError "     interface for the PBA by setting OPAL_PBA_{PROGS,COPY_AS_IS,LIBS} to include Plymouth components."
fi
PROGS+=( "${OPAL_PBA_PROGS[@]}" clear )
{ test "$OPAL_PBA_DEBUG_PASSWORD" ; } 2>>/dev/$SECRET_OUTPUT_DEV && REQUIRED_PROGS+=( openssl )
COPY_AS_IS+=( "${OPAL_PBA_COPY_AS_IS[@]}" )
LIBS+=( "${OPAL_PBA_LIBS[@]}" )

is_false "$OPAL_PBA_SBWARN" || REQUIRED_PROGS+=( 'od' )
if [ -n "$OPAL_PBA_TKNPATH" ]; then # AuthToken support
    REQUIRED_PROGS+=( 'openssl' 'base64' 'dd' 'lsblk' )
    is_true "$OPAL_PBA_TKNBIND" && REQUIRED_PROGS+=( 'b2sum' )
    if [ "${OPAL_PBA_TKNKEY:0:4}" == "tpm:" ]; then # TPM2-assisted encryption
        REQUIRED_PROGS+=( 'systemd-creds' )
        LIBS+=( /usr/lib/x86_64-linux-gnu/libtss2-*.so* )
    fi
fi

if [ -z "$OPAL_PBA_TKNPATH" ] && [ -n "$OPAL_PBA_TPMNVINDEX" ]; then # TPM support
    REQUIRED_PROGS+=( 'tpm2_nvundefine' 'tpm2_nvdefine' 'tpm2_nvread' 'tpm2_nvwrite' )
    LIBS+=( /usr/lib/x86_64-linux-gnu/libtss2-*.so* )
fi

# Redirect output
[[ -n "$OPAL_PBA_OUTPUT_URL" ]] || Error "The OPAL_PBA_OUTPUT_URL configuration variable must be set."
OUTPUT_URL="$OPAL_PBA_OUTPUT_URL"
if [[ "$(url_scheme "$OPAL_PBA_OUTPUT_URL")" == "file" ]]; then
    # Do not include any PBA into another PBA
    COPY_AS_IS_EXCLUDE+=( "$(url_path "$OPAL_PBA_OUTPUT_URL")" )
fi

# Configure raw disk output
RAWDISK_IMAGE_NAME="TCG-Opal-PBA-$HOSTNAME"
RAWDISK_IMAGE_COMPRESSION_COMMAND=""   # Do not compress the PBA image
RAWDISK_GPT_PARTITION_NAME="TCG Opal PBA"
RAWDISK_FAT_VOLUME_LABEL="OPAL PBA"
RAWDISK_BOOT_GRUB_MENUENTRY_TITLE="TCG Opal pre-boot authentication"
RAWDISK_BOOT_SYSLINUX_START_INFORMATION="Starting TCG Opal pre-boot authentication..."
RAWDISK_INSTALL_GPT_PARTITION_NAME=''  # Never install a PBA in a rescue system partition
