# List executables along with the shared libraries they depend on
#
# The resulting list can be used to determine which executables with a large footprint could be stripped from the
# TCG Opal pre-boot authentication (PBA) image

if is_true $KEEP_BUILD_DIR; then
    executables=( $(cd "$ROOTFS_DIR"; find . -type f -executable -print | sort) )
    executable_dependencies_list="$TMP_DIR/executable-dependencies"

    for executable in "${executables[@]}"; do
        dependents=( $(RequiredSharedOjects "$ROOTFS_DIR/$executable") )
        echo "$executable: ${dependents[*]}"
    done > "$executable_dependencies_list"

    LogPrint "A list of executables with their dependencies has been stored in $executable_dependencies_list"
fi
