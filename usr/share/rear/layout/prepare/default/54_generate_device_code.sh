# Use the dependencies to order device creation

# generate code
willdodev="start"
willdotype=

while [ -n "$willdodev" ] ; do
    # write the code to create a device
    if ! [ "$willdodev" = "start" ] ; then
        create_device $willdodev $willdotype
        
        mark_as_done $willdodev
        
        willdodev=
        willdotype=
    fi

    # cycle through all devices and find one that can be done
    cp $LAYOUT_TODO $LAYOUT_TODO.tmp
    while read status thisdev type; do
        Log "Testing $thisdev for dependencies..."
        # test if all dependencies are already created.
        deps=($(grep "^$thisdev\ " $LAYOUT_DEPS | cut -d " " -f "2"))
        Log "deps (${#deps[@]}): ${deps[*]}"
        
        donedeps=0
        for dep in "${deps[@]}" ; do
            if grep "done $dep " $LAYOUT_TODO.tmp > /dev/null ; then
                let donedeps=donedeps+1
            fi
        done
        
        if [ ${#deps[@]} -eq $donedeps ] ; then
            Log "All dependencies for $thisdev are present, processing..."
            willdodev="$thisdev"
            willdotype="$type"
            break
        fi
    done < <(grep "^todo" $LAYOUT_TODO)
    rm $LAYOUT_TODO.tmp
done
