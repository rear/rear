# Include tools for TCG Opal support

has_binary sedutil-cli || return 0

PROGS+=( sedutil-cli lsblk )
KERNEL_CMDLINE+=" libata.allow_tpm=1"

# Exclude specific udev rules producing error messages when sedutil-cli accesses disks.
COPY_AS_IS_EXCLUDE+=( /lib/udev/rules.d/*-snap*.rules )

if [[ "$WORKFLOW" == "mkrescue" ]]; then
    local pba_image_file="$(opal_local_pba_image_file)"
    if [[ -n "$pba_image_file" ]]; then
        COPY_AS_IS+=( "$pba_image_file" )
        LogPrint "Using local PBA image file \"$pba_image_file\""
    fi
fi
