# Store settings for the PBA runtime

if [[ "$OPAL_PBA_UNLOCK_MODE" == "permanent" ]]; then
    LogUserOutput "WARNING: TCG Opal 2 PBA will *permanently* unlock disks (OPAL_PBA_UNLOCK_MODE='$OPAL_PBA_UNLOCK_MODE')"
fi

cat > "$ROOTFS_DIR/.OPAL_PBA_SETTINGS.sh" << -EOF-
OPAL_PBA_UNLOCK_MODE='$OPAL_PBA_UNLOCK_MODE'
OPAL_PBA_DEBUG_PASSWORD='$OPAL_PBA_DEBUG_PASSWORD'
OPAL_PBA_DEBUG_DEVICE_COUNT='$OPAL_PBA_DEBUG_DEVICE_COUNT'

OPAL_PBA_TPMNVINDEX='$OPAL_PBA_TPMNVINDEX'
OPAL_PBA_TPMDBG='$OPAL_PBA_TPMDBG'

OPAL_PBA_SBWARN='$OPAL_PBA_SBWARN'
OPAL_PBA_NOSUCCESSMSG='$OPAL_PBA_NOSUCCESSMSG'
OPAL_PBA_GPT_PARTITION_NAME='$RAWDISK_GPT_PARTITION_NAME'

OPAL_PBA_TKNPATH=( ${OPAL_PBA_TKNPATH[@]} )
OPAL_PBA_TKNOFFSET=$OPAL_PBA_TKNOFFSET
OPAL_PBA_TKNKEY='$OPAL_PBA_TKNKEY'
OPAL_PBA_TKNBIND='$OPAL_PBA_TKNBIND'

OPAL_PBA_TKN2FAMAXTRIES=$OPAL_PBA_TKN2FAMAXTRIES
OPAL_PBA_TKN2FAFAILWIPE='$OPAL_PBA_TKN2FAFAILWIPE'

OPAL_PBA_TKNDBG='$OPAL_PBA_TKNDBG'
-EOF-
