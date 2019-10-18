# Use the dependencies to order device processing and generate code for them.

# LAYOUT_CODE is the script to mount the target system based on its disk 
# layout (diskrestore.sh).

save_original_file "$LAYOUT_CODE"

# Initialize diskrestore.sh:
cat <<EOF >"$LAYOUT_CODE"
#!/bin/bash

LogPrint "Start target system mount."

mkdir -p $TARGET_FS_ROOT
if create_component "vgchange" "rear" ; then
    lvm vgchange -a y >/dev/null
    component_created "vgchange" "rear"
fi

set -e
set -x

EOF

# Populate diskrestore.sh with further code to (re)-mount all disk layout components:
all_done=
while [ -z "$all_done" ] ; do
    # Cycle through all components and find one that can be mounted.
    willdodev=
    willdotype=

    cp "$LAYOUT_TODO" "${LAYOUT_TODO}.tmp"
    while read status thisdev type; do
        # Test if all dependencies are already created.
        Debug "Testing $thisdev for dependencies..."
        deps=($(grep "^$thisdev\ " "$LAYOUT_DEPS" | cut -d " " -f "2"))
        Debug "deps (${#deps[@]}): ${deps[*]}"

        donedeps=0
        for dep in "${deps[@]}" ; do
            if grep -q "done $dep " "$LAYOUT_TODO.tmp"; then
                let donedeps++
            fi
        done

        if [ ${#deps[@]} -eq $donedeps ] ; then
            Debug "All dependencies for $thisdev are present, processing..."
            willdodev="$thisdev"
            willdotype="$type"
            break
        fi
    done < <(grep "^todo" "$LAYOUT_TODO")
    rm "$LAYOUT_TODO.tmp"

    # Write the code to mount a device.
    if [ -n "$willdodev" ] ; then
        do_mount_device "$willdodev" "$willdotype"

        mark_as_done "$willdodev"
    else
        # No device to be mounted, no additional dependencies can be satisfied.
        all_done="y"
    fi

done

# Now mount needed virtual filesystems below the target root to support
# chrooting into it and running YaST (a.o.)
cat <<EOF >>"$LAYOUT_CODE"

LogPrint "Mounting virtual filesystems below target root."

mount -t proc proc $TARGET_FS_ROOT/proc
mount -t sysfs sysfs $TARGET_FS_ROOT/sys
mount -o rbind /dev $TARGET_FS_ROOT/dev

LogPrint "Target system now ready for chrooting into it."

EOF
