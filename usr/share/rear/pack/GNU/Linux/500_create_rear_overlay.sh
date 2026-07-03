
# 500_create_rear_overlay.sh
#
# Split the rescue system into a small initramfs and a SquashFS overlay.
# The overlay contains firmware files and non-essential kernel modules.
# At boot time, a startup script mounts the overlay from the ISO and
# copies its content into the running rescue system.
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# Determine overlay mode: "copy" or "mount"
local overlay_mode=""
case "$REAR_INITRD_OVERLAY" in
    (copy)     overlay_mode="copy" ;;
    (mount)    overlay_mode="mount" ;;
    (*)        return 0 ;;
esac

case "$OUTPUT" in
    (ISO|PXE|USB) ;;
    (*) Error "REAR_INITRD_OVERLAY is only supported with OUTPUT=ISO, OUTPUT=PXE or OUTPUT=USB (current OUTPUT=$OUTPUT)" ;;
esac

type mksquashfs &>/dev/null || Error "REAR_INITRD_OVERLAY requires 'mksquashfs' (install the squashfs-tools package)"

test "$KERNEL_VERSION" || BugError "KERNEL_VERSION is not set"

local overlay_dir="$TMP_DIR/rear-overlay-content"
local overlay_sqsh="$TMP_DIR/rear-overlay.sqsh"
local overlay_filename="rear-overlay.sqsh"

local rootfs_size_before=$( du -sm "$ROOTFS_DIR" | cut -f1 )
LogPrint "Creating recovery system overlay (rootfs is $rootfs_size_before MiB before split)"

# Resolve the actual lib path (may be a symlink, e.g. lib -> usr/lib)
local lib_realpath=$( readlink -f "$ROOTFS_DIR/lib" )
local lib_relpath="${lib_realpath#$ROOTFS_DIR/}"

mkdir -p "$overlay_dir/$lib_relpath"

# Move firmware files to overlay
if test -d "$ROOTFS_DIR/$lib_relpath/firmware" ; then
    local firmware_size=$( du -sm "$ROOTFS_DIR/$lib_relpath/firmware" | cut -f1 )
    LogPrint "Moving firmware files ($firmware_size MiB) to overlay"
    mv "$ROOTFS_DIR/$lib_relpath/firmware" "$overlay_dir/$lib_relpath/firmware"
    mkdir -p "$ROOTFS_DIR/$lib_relpath/firmware"
fi

# Move non-essential kernel modules to overlay.
# Keep only modules needed at boot time to access the overlay:
#   ISO: storage controllers and CD/DVD drivers to mount the ISO device
#   PXE: network drivers to download the overlay from TFTP/HTTP server
# Common: filesystems (squashfs, overlayfs) and compression libraries
local modules_dir="$ROOTFS_DIR/$lib_relpath/modules/$KERNEL_VERSION"
if test -d "$modules_dir/kernel" ; then
    local modules_size_before=$( du -sm "$modules_dir" | cut -f1 )

    mkdir -p "$overlay_dir/$lib_relpath/modules/$KERNEL_VERSION/kernel"

    if IsInArray "all_modules" "${MODULES[@]}" ; then
        # MODULES=('all_modules'): use directory-based approach to keep
        # entire driver categories needed to access the overlay device.
        local essential_dirs="
            kernel/fs/squashfs
            kernel/fs/overlayfs
            kernel/fs/nls
            kernel/drivers/block
            kernel/lib
        "

        if is_true "$GRUB_RESCUE" ; then
            if test "$GRUB_RESCUE_BOOT_FSTYPE" ; then
                case "$GRUB_RESCUE_BOOT_FSTYPE" in
                    (ext[234]) essential_dirs+=" kernel/fs/ext4 kernel/fs/jbd2" ;;
                    (*)        essential_dirs+=" kernel/fs/$GRUB_RESCUE_BOOT_FSTYPE" ;;
                esac
            fi
            if test "$GRUB_RESCUE_BOOT_DRIVER" ; then
                local boot_driver_modpath=$( modinfo -k $KERNEL_VERSION -F filename "$GRUB_RESCUE_BOOT_DRIVER" 2>/dev/null )
                if test "$boot_driver_modpath" ; then
                    local boot_driver_dir="${boot_driver_modpath#*/kernel/}"
                    boot_driver_dir="kernel/${boot_driver_dir%/*}"
                    essential_dirs+=" $boot_driver_dir"
                fi
            fi
        fi

        case "$OUTPUT" in
            (ISO)
                essential_dirs+="
                    kernel/drivers/ata
                    kernel/drivers/scsi
                    kernel/drivers/cdrom
                    kernel/drivers/usb
                    kernel/drivers/virtio
                    kernel/drivers/message
                    kernel/drivers/firewire
                    kernel/drivers/hv
                    kernel/fs/isofs
                    kernel/fs/udf
                "
                ;;
            (USB)
                essential_dirs+="
                    kernel/drivers/ata
                    kernel/drivers/scsi
                    kernel/drivers/usb
                    kernel/drivers/virtio
                    kernel/drivers/message
                    kernel/drivers/firewire
                    kernel/drivers/hv
                    kernel/fs/ext4
                    kernel/fs/jbd2
                "
                ;;
            (PXE)
                essential_dirs+="
                    kernel/drivers/net
                "
                ;;
        esac

        test "$ARCH" = "Linux-s390" && essential_dirs+=" kernel/drivers/s390"

        # Move each subdirectory under kernel/ to overlay unless it is essential
        for subdir in "$modules_dir/kernel"/*/ ; do
            test -d "$subdir" || continue
            local dirname=$( basename "$subdir" )
            local keep="no"
            for essential in $essential_dirs ; do
                if test "kernel/$dirname" = "$( echo "$essential" | cut -d/ -f1-2 )" ; then
                    keep="yes"
                    break
                fi
            done
            if is_true "$keep" ; then
                if test "$dirname" = "drivers" || test "$dirname" = "fs" ; then
                    mkdir -p "$overlay_dir/$lib_relpath/modules/$KERNEL_VERSION/kernel/$dirname"
                    for sub2dir in "$subdir"*/ ; do
                        test -d "$sub2dir" || continue
                        local sub2name=$( basename "$sub2dir" )
                        local keep_sub="no"
                        for essential in $essential_dirs ; do
                            if test "kernel/$dirname/$sub2name" = "$essential" ; then
                                keep_sub="yes"
                                break
                            fi
                        done
                        if ! is_true "$keep_sub" ; then
                            mv "$sub2dir" "$overlay_dir/$lib_relpath/modules/$KERNEL_VERSION/kernel/$dirname/"
                        fi
                    done
                fi
            else
                mv "$subdir" "$overlay_dir/$lib_relpath/modules/$KERNEL_VERSION/kernel/"
            fi
        done

    else
        # MODULES is restricted (loaded_modules, empty, or explicit list).
        # Only keep modules that are currently loaded plus a small set needed
        # for overlay access. Move everything else to the overlay.
        # The dependency resolution step below will pull in any missing deps.
        local essential_modules="loop squashfs overlay"
        case "$OUTPUT" in
            (ISO)  essential_modules+=" isofs udf sr_mod cdrom" ;;
            (USB)  essential_modules+=" ext4 jbd2" ;;
        esac
        if is_true "$GRUB_RESCUE" && test "$GRUB_RESCUE_BOOT_FSTYPE" ; then
            essential_modules+=" $GRUB_RESCUE_BOOT_FSTYPE"
            case "$GRUB_RESCUE_BOOT_FSTYPE" in
                (ext[234]) essential_modules+=" ext4 jbd2" ;;
            esac
        fi

        # Build list of modules to keep: loaded + essential
        local keep_modules=" $essential_modules "
        while read mod_name rest ; do
            keep_modules+="$mod_name "
        done < /proc/modules

        # Move non-kept modules to overlay, one by one
        while IFS= read -r -d '' ko_file ; do
            local mod_basename="${ko_file##*/}"
            local mod_name="${mod_basename%%.*}"
            if test "${keep_modules/ $mod_name / }" = "$keep_modules" ; then
                # Module is not in keep list, move to overlay
                local ko_relpath="${ko_file#$modules_dir/}"
                local ko_overlay_dir="$overlay_dir/$lib_relpath/modules/$KERNEL_VERSION/$( dirname "$ko_relpath" )"
                mkdir -p "$ko_overlay_dir"
                mv "$ko_file" "$ko_overlay_dir/"
            fi
        done < <( find "$modules_dir/kernel" -name '*.ko*' -print0 )

        # Clean up empty directories left behind
        find "$modules_dir/kernel" -type d -empty -delete 2>/dev/null
    fi

    # Pull in module dependencies: some essential modules depend on modules
    # that landed in the overlay (e.g. hv_storvsc needs hv_vmbus, qla2xxx
    # needs scsi_transport_fc and nvme modules). Resolve the full dependency
    # tree and copy back any missing modules from the overlay.
    local dep_count=0
    while IFS= read -r -d '' ko_file ; do
        local mod_basename="${ko_file##*/}"
        local mod_name="${mod_basename%%.*}"
        while IFS= read -r dep_line ; do
            # modprobe --show-depends outputs "insmod /lib/modules/.../foo.ko.xz"
            # but /lib may be a symlink to usr/lib, so resolve the real path
            local dep_path="${dep_line#insmod }"
            dep_path="${dep_path%% }"
            local dep_realpath="$( readlink -f "$ROOTFS_DIR$dep_path" 2>/dev/null )"
            test -f "$dep_realpath" && continue
            # Module is missing from initramfs, look for it in the overlay
            # Convert /lib/modules/... or /usr/lib/modules/... to a relative path
            local dep_modrelpath="${dep_path}"
            dep_modrelpath="${dep_modrelpath#/lib/modules/}"
            dep_modrelpath="${dep_modrelpath#/usr/lib/modules/}"
            local dep_overlay="$overlay_dir/$lib_relpath/modules/$dep_modrelpath"
            local dep_dst="$ROOTFS_DIR/$lib_relpath/modules/$dep_modrelpath"
            if test -f "$dep_overlay" ; then
                mkdir -p "$( dirname "$dep_dst" )"
                cp -a "$dep_overlay" "$dep_dst"
                dep_count=$(( dep_count + 1 ))
            fi
        done < <( modprobe -S $KERNEL_VERSION --show-depends "$mod_name" 2>/dev/null | grep '^insmod ' )
    done < <( find "$modules_dir" -name '*.ko*' -print0 )
    test $dep_count -gt 0 && LogPrint "Pulled $dep_count module dependencies into initramfs"

    local modules_size_after=$( du -sm "$modules_dir" | cut -f1 )
    LogPrint "Kept $modules_size_after MiB of essential kernel modules in initramfs (was $modules_size_before MiB)"

    # Regenerate module dependency files for the reduced set in initramfs
    Log "Running depmod for reduced initramfs modules"
    depmod -b "$ROOTFS_DIR" $KERNEL_VERSION

    # Copy back firmware files required by the essential modules.
    # Some drivers (e.g. bnx2, tg3, qla2xxx) need firmware to initialize.
    # Without their firmware in the initramfs, those drivers cannot function
    # at boot time to access the overlay.
    if test -d "$overlay_dir/$lib_relpath/firmware" ; then
        local fw_count=0
        while IFS= read -r -d '' ko_file ; do
            while IFS= read -r fw_name ; do
                test -n "$fw_name" || continue
                # Firmware files may be compressed (.xz, .zst) on disk
                local fw_src=""
                for candidate in \
                    "$overlay_dir/$lib_relpath/firmware/$fw_name" \
                    "$overlay_dir/$lib_relpath/firmware/$fw_name.xz" \
                    "$overlay_dir/$lib_relpath/firmware/$fw_name.zst" ; do
                    test -f "$candidate" && fw_src="$candidate" && break
                done
                test -n "$fw_src" || continue
                local fw_dst="$ROOTFS_DIR/$lib_relpath/firmware/${fw_src#$overlay_dir/$lib_relpath/firmware/}"
                if ! test -f "$fw_dst" ; then
                    mkdir -p "$( dirname "$fw_dst" )"
                    cp -a "$fw_src" "$fw_dst"
                    fw_count=$(( fw_count + 1 ))
                fi
            done < <( modinfo -k $KERNEL_VERSION -F firmware "$ko_file" 2>/dev/null )
        done < <( find "$modules_dir" -name '*.ko*' -print0 )
        test $fw_count -gt 0 && LogPrint "Kept $fw_count firmware files required by essential modules"

        # Also keep firmware files explicitly listed in REAR_INITRD_FIRMWARE_FILES
        if test ${#REAR_INITRD_FIRMWARE_FILES[@]} -gt 0 ; then
            local manual_fw_count=0
            for fw_pattern in "${REAR_INITRD_FIRMWARE_FILES[@]}" ; do
                while IFS= read -r -d '' fw_file ; do
                    local fw_rel="${fw_file#$overlay_dir/$lib_relpath/firmware/}"
                    local fw_dst="$ROOTFS_DIR/$lib_relpath/firmware/$fw_rel"
                    if ! test -f "$fw_dst" ; then
                        mkdir -p "$( dirname "$fw_dst" )"
                        cp -a "$fw_file" "$fw_dst"
                        manual_fw_count=$(( manual_fw_count + 1 ))
                    fi
                done < <( find "$overlay_dir/$lib_relpath/firmware" -path "*/$fw_pattern" -print0 2>/dev/null )
            done
            test $manual_fw_count -gt 0 && LogPrint "Kept $manual_fw_count additional firmware files from REAR_INITRD_FIRMWARE_FILES"
        fi
    fi
fi

# Create the SquashFS overlay image
local start_seconds=$( date +%s )
LogPrint "Creating SquashFS overlay image $overlay_filename"
if ! mksquashfs "$overlay_dir" "$overlay_sqsh" -comp xz -no-progress 2>>/dev/$DISPENSABLE_OUTPUT_DEV ; then
    Error "Failed to create SquashFS overlay image"
fi
local needed_seconds=$(( $( date +%s ) - start_seconds ))
local overlay_bytes=$( stat -L -c '%s' "$overlay_sqsh" )
local overlay_MiB=$( mathlib_calculate "$overlay_bytes / 1048576" )
local rootfs_size_after=$( du -sm "$ROOTFS_DIR" | cut -f1 )

LogPrint "Created $overlay_filename ($overlay_MiB MiB) in $needed_seconds seconds"
LogPrint "Rootfs reduced from $rootfs_size_before MiB to $rootfs_size_after MiB"

# Write marker file so the boot script knows to look for the overlay
cat > "$ROOTFS_DIR/etc/rear-overlay.conf" <<EOF
# ReaR overlay configuration - generated by 500_create_rear_overlay.sh
REAR_OVERLAY_FILENAME="$overlay_filename"
REAR_OVERLAY_MODE="$overlay_mode"
REAR_OVERLAY_OUTPUT="$OUTPUT"
EOF
# For USB output, store the path and filesystem label so the boot script
# can find and mount the USB device to access the overlay
if test "$OUTPUT" = "USB" ; then
    cat >> "$ROOTFS_DIR/etc/rear-overlay.conf" <<EOF
REAR_OVERLAY_USB_PREFIX="$USB_PREFIX"
REAR_OVERLAY_USB_LABEL="$USB_DEVICE_FILESYSTEM_LABEL"
EOF
fi

# Regenerate md5sums for the reduced rootfs so that verification at boot time
# does not report missing files that are now in the overlay
if test -f "$ROOTFS_DIR/md5sums.txt" ; then
    Log "Regenerating md5sums.txt for reduced rootfs"
    pushd "$ROOTFS_DIR" 1>&2
    # Exclude module metadata files (modules.dep, modules.alias, etc.)
    # because depmod -a regenerates them at boot after the overlay is applied
    find . -xdev -type f -print0 | grep -E -z -v '/md5sums\.txt|/\.gitignore|~$|/dev/|/modules\.(dep|alias|symbols|devname|softdep)(\.bin)?$' | xargs -0 md5sum -b > md5sums.txt || cat /dev/null > md5sums.txt
    popd 1>&2
fi
