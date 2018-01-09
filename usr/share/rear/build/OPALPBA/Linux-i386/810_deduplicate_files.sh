# De-duplicates executables to minimize the file system's footprint

has_binary sha256sum || return 0

local deduplication_script="$TMP_DIR/deduplicate-files.sh"

# Calculate checksums of executables in the root file system to identify files with identical content.
# Then use hard links to cross-link such files.
find "$ROOTFS_DIR" -type f -executable -exec sha256sum --binary '{}' + | sort |
awk -v path_prefix="$ROOTFS_DIR" '
    BEGIN {
        path_prefix_length = length(path_prefix);
    }
    {
        hash = $1;
        sub(/^[^ ]+ ./, "");
        path = $0;

        if (hash in executables) {
            if (substr(path, 1, path_prefix_length) == path_prefix) {
                printf("Log '"'"'De-duplicating \"%s\" -> \"%s\"'"'"'\n", executables[hash], path);
                printf("ln --force '"'"'%s'"'"' '"'"'%s'"'"' || Error '"'"'De-duplication error'"'"'\n", executables[hash], path);
            } else {
                printf("LogUserOutput '"'"'Cannot de-duplicate \"%s\" -> \"%s\"'"'"'\n", executables[hash], path);
            }
        } else {
            executables[hash] = path;
        }
    }
' > "$deduplication_script"

source "$deduplication_script"
