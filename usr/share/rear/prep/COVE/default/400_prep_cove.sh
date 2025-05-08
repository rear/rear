#
# Prepare stuff for Cove
#

REQUIRED_PROGS+=( "${REQUIRED_PROGS_COVE[@]}" )

if has_binary curl ; then
    REQUIRED_PROGS+=( curl )
else
    REQUIRED_PROGS+=( wget )
fi

for executable in BackupFP ClientTool ProcessController; do
    for required_library in $(RequiredSharedObjects "${COVE_INSTALL_DIR}/bin/${executable}"); do
        IsInArray "$required_library" "${LIBS[@]}" && continue
        LIBS+=( "$required_library" )
    done
done

KERNEL_CMDLINE+=" ${KERNEL_CMDLINE_COVE} "
