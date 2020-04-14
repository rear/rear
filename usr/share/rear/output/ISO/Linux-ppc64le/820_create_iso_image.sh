
Log "Starting '$ISO_MKISOFS_BIN'"
LogPrint "Making ISO image"

pushd $TMP_DIR

# If isofs directory exists, add its content to ISO_FILES (when backup must be part of the ISO images)
if [ -d isofs ] ; then
    ISO_FILES=( ${ISO_FILES[@]} isofs )
fi

# mkisofs command for ppc64/ppc64le arch
# Adapt the chrp-boot option if xorrisofs is used.
if [[ "$(basename $ISO_MKISOFS_BIN)" == "xorrisofs" ]] ; then
    chrp_boot_option="-chrp-boot-part"
else
    chrp_boot_option="-chrp-boot"
fi

# Have a hardcoded '-iso-level 3' option also here because it is
# also hardcoded in output/ISO/Linux-i386/820_create_iso_image.sh
# and it seems to also work in general on POWER architecture
# cf. https://github.com/rear/rear/issues/2344#issuecomment-601949828
$ISO_MKISOFS_BIN $v $ISO_MKISOFS_OPTS -o "$ISO_DIR/$ISO_PREFIX.iso" \
    -U $chrp_boot_option -R -J -volid "$ISO_VOLID" -v -iso-level 3 -graft-points \
    "${ISO_FILES[@]}"

StopIfError "Could not create ISO image (with $ISO_MKISOFS_BIN)"
popd

iso_image_size=( $(du -h "$ISO_DIR/$ISO_PREFIX.iso") )
LogPrint "Wrote ISO image: $ISO_DIR/$ISO_PREFIX.iso ($iso_image_size)"

# Add ISO image to result files
RESULT_FILES+=( "$ISO_DIR/$ISO_PREFIX.iso" )

# vim: set et ts=4 sw=4:
