# Use the dependencies to order device creation and generate code for them.

# $LAYOUT_CODE will contain the script to restore the environment.
backup_file "$LAYOUT_CODE"
cat <<EOF >"$LAYOUT_CODE"
#!/bin/bash

LogPrint "Start system layout restoration."

mkdir -p $TARGET_FS_ROOT
if create_component "vgchange" "rear" ; then
    lvm vgchange -a n >/dev/null
    component_created "vgchange" "rear"
fi

set -e
set -x

EOF

all_done=
while [ -z "$all_done" ] ; do
    # Cycle through all components and find one that can be created.
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

    # Write the code to create a device.
    if [ -n "$willdodev" ] ; then
        create_device "$willdodev" "$willdotype"

        mark_as_done "$willdodev"
    else
        # No device to be created, no additional dependencies can be satisfied.
        all_done="y"
    fi

done
