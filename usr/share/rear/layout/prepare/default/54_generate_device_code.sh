# Use the dependencies to order device creation and generate code for them

all_done=
while [ -z "$all_done" ] ; do
    # cycle through all components and find one that can be created
    willdodev=
    willdotype=
    
    cp $LAYOUT_TODO $LAYOUT_TODO.tmp
    while read status thisdev type; do
        Debug "Testing $thisdev for dependencies..."
        # test if all dependencies are already created.
        deps=($(grep "^$thisdev\ " $LAYOUT_DEPS | cut -d " " -f "2"))
        Debug "deps (${#deps[@]}): ${deps[*]}"
        
        donedeps=0
        for dep in "${deps[@]}" ; do
            if grep -q "done $dep " $LAYOUT_TODO.tmp; then
                let donedeps=donedeps+1
            fi
        done
        
        if [ ${#deps[@]} -eq $donedeps ] ; then
            Debug "All dependencies for $thisdev are present, processing..."
            willdodev="$thisdev"
            willdotype="$type"
            break
        fi
    done < <(grep "^todo" $LAYOUT_TODO)
    rm $LAYOUT_TODO.tmp
    
    # write the code to create a device
    if [ -n "$willdodev" ] ; then
        create_device $willdodev $willdotype
        
        mark_as_done $willdodev
    else
        # no device to be created, no additional dependencies can be satisfied
        all_done="y"
    fi

done
