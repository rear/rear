# Configure the workflow for TCG Opal pre-boot authentication (PBA) image creation

has_binary sedutil-cli || Error "Executable sedutil-cli is missing. Cannot create a TCG Opal PBA without it."

LogPrint "Re-configuring Relax-and-Recover to create a TCG Opal pre-boot authentication (PBA) image"

# Configure kernel
KERNEL_CMDLINE+=" quiet splash systemd.volatile=yes systemd.unit=opalpba.target"

# Enable debugging in PBA on request
is_true "$OPALPBA_DEBUG" && KERNEL_CMDLINE+=" opal_debug"

# Strip kernel files to a reasonable minimum
FIRMWARE_FILES=( 'no' )
MODULES=( 'loaded_modules' )
EXCLUDE_MODULES+=( $(lsmod | tail -n +2 | cut -d ' ' -f 1 | while read m; do modprobe -R $m; done | grep '^nvidia' ) )

# Include plymouth boot animation if available
PROGS+=( plymouth plymouthd clear )
COPY_AS_IS+=( /usr/lib/x86_64-linux-gnu/plymouth /usr/share/plymouth /etc/alternatives )

# Redirect output
[[ -n "$OPALPBA_URL" ]] || Error "The OPALPBA_URL configuration variable must be set."
OUTPUT_URL="$OPALPBA_URL"

# Configure raw disk output
RAWDISK_GRUB_BOOT_MENUENTRY_TITLE="TCG Opal pre-boot authentication"
RAWDISK_PARTITION_NAME="TCG Opal PBA"
RAWDISK_BOOT_FS_NAME="OPAL PBA"
RAWDISK_SYSLINUX_START_INFORMATION="Starting TCG Opal pre-boot authentication..."
RAWDISK_IMAGE_NAME="TCG-Opal-PBA-$HOSTNAME"
