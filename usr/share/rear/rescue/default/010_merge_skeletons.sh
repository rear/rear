# rescue/default/010_merge_skeletons.sh
#
# Merge the skeleton directories for Relax-and-Recover.
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

local skel_path="$SHARE_DIR/skel"
local skel_dir

LogPrint "Creating recovery system root filesystem skeleton layout"

pushd $skel_path >/dev/null
for skel_dir in default "$ARCH" "$OS" \
        "$OS_MASTER_VENDOR/default" "$OS_MASTER_VENDOR_ARCH" "$OS_MASTER_VENDOR_VERSION" \
        "$OS_VENDOR/default" "$OS_VENDOR_ARCH" "$OS_VENDOR_VERSION" \
        "$BACKUP" "$OUTPUT" ; do
    # Silently skip when $skel_dir is empty (e.g. when $OS_MASTER_* is empty):
    test "$skel_dir" || continue
    # Skip if there is neither a $skel_dir directory nor a $skel_dir.tar.gz:
    if ! test -d "$skel_dir" -o -s "$skel_dir.tar.gz" ; then
        Debug "Neither a '$skel_path/$skel_dir' directory nor a '$skel_path/$skel_dir.tar.gz'"
        continue   
    fi
    # When $skel_dir is a directory (e.g. usr/share/rear/skel/default/) copy all its contents:
    if test -d "$skel_dir" ; then
        Log "Copying '$skel_path/$skel_dir' contents to $ROOTFS_DIR"
        tar -C "$skel_dir" -c . | tar -C $ROOTFS_DIR -x || Error "Failed to copy '$skel_path/$skel_dir' contents to $ROOTFS_DIR"
    fi
    # If $skel_dir.tar.gz exists (e.g. usr/share/rear/skel/Debian/default.tar.gz) extract it:
    if test -s "$skel_dir.tar.gz" ; then
        Log "Extracting '$skel_path/$skel_dir.tar.gz' into $ROOTFS_DIR"
        tar -C $ROOTFS_DIR -xzf "$skel_dir.tar.gz" || Error "Failed to extract '$skel_path/$skel_dir.tar.gz' into $ROOTFS_DIR"
    fi
done
popd >/dev/null

# Ensure the owner is root (e.g. when running from checkout):
chown -R root:root $ROOTFS_DIR || Error "Failed to 'chown root' $ROOTFS_DIR contents"
