
# Disable excluded components in var/lib/rear/layout/disklayout.conf
# Excluded components have been marked as 'done ...' in var/lib/rear/layout/disktodo.conf

test -s "$LAYOUT_TODO" || return 0

# Below there is a (perhaps oversophisticated?) distinction what messages should appear
# - only in the log file in debug '-d' mode via 'Debug'
# - in the log file and on the user's terminal in debug '-d' mode via 'DebugPrint'
# - in the log file and on the user's terminal in verbose '-v' mode via 'LogPrint'
# so that the info that is shown on the user's terminal (hopefully) looks consistent.
# This distinction matches the same kind of distinction in the
# mark_as_done and mark_tree_as_done functions in lib/layout-functions.sh

DebugPrint "Disabling excluded components in $LAYOUT_FILE"

# Disable component $1 $2 in disklayout.conf
# where $1 is the component keyword/type that is always at the first position
# and the component value/name $2 is at the second position:
disable_component_at_second_position() {
    # The trailing blank in "... $2 " is crucial to not match wrong components
    # for example the component "part /dev/sda1" must not match accidentally
    # other components like "part /dev/sda12" in var/lib/rear/layout/disklayout.conf
    if grep -q "#$1 $2 " $LAYOUT_FILE ; then
        DebugPrint "Component '$1 $2' is disabled in $LAYOUT_FILE"
        return 0
    fi
    if ! grep -q "^$1 $2 " $LAYOUT_FILE ; then
        Debug "Cannot disable component because there is no '^$1 $2 ' in $LAYOUT_FILE"
        return 1
    fi
    LogPrint "Disabling component '$1 $2' in $LAYOUT_FILE"
    sed -i "s|^$1 $2 |\#$1 $2 |" "$LAYOUT_FILE"
}

# Disable component $1 ... $2 in disklayout.conf
# where $1 is the component keyword/type that is always at the first position
# and the component value/name $2 is at the third position:
disable_component_at_third_position() {
    # The trailing blank in "... $2 " is crucial to not match wrong components
    # for example the component "part /dev/sda1" must not match accidentally
    # other components like "part /dev/sda12" in var/lib/rear/layout/disklayout.conf
    if grep -q "#$1 [^ ][^ ]* $2 " $LAYOUT_FILE ; then
        DebugPrint "Component '$1 ... $2' is disabled in $LAYOUT_FILE"
        return 0
    fi
    if ! grep -q "^$1 [^ ][^ ]* $2 " $LAYOUT_FILE ; then
        Debug "Cannot disable component because there is no '^$1 ... $2 ' in $LAYOUT_FILE"
        return 1
    fi
    LogPrint "Disabling component '$1 ... $2' in $LAYOUT_FILE"
    sed -i -r "s|^$1 ([^ ]+) $2 |\#$1 \1 $2 |" "$LAYOUT_FILE"
}

# In disktodo.conf the component status ('todo'/'done') is always at the first position
# and the component value/name is always at the second position
# and the component keyword/type is always at the third position:
while read status name type junk ; do
    case "$type" in
        (part)
            # find the immediate parent
            name=$( grep "^$name " "$LAYOUT_DEPS" | cut -d " " -f 2 )
            disable_component_at_second_position "$type" "$name"
            ;;
        (lvmvol)
            name=${name#/dev/mapper/}
            # split between vg and lv is single dash
            # Device mapper doubles dashes in vg and lv
            vg=$( sed "s/\([^-]\)-[^-].*/\1/;s/--/-/g" <<< "$name" )
            lv=$( sed "s/.*[^-]-\([^-]\)/\1/;s/--/-/g" <<< "$name" )
            sed -i -r "s|^($type /dev/$vg $lv )|\#\1|" "$LAYOUT_FILE"
            ;;
        (fs|btrfsmountedsubvol|lvmdev)
            name=${name#$type:}
            disable_component_at_third_position "$type" "$name"
            ;;
        (opaldisk)
            name=${name#$type:}
            disable_component_at_second_position "$type" "$name"
            ;;
        (swap)
            name=${name#swap:}
            disable_component_at_second_position "$type" "$name"
            ;;
        (*)
            disable_component_at_second_position "$type" "$name"
            ;;
    esac
done < <( grep "^done" "$LAYOUT_TODO" )

# Disable all LVM PVs of excluded VGs:
while read status name junk ; do
    disable_component_at_second_position "lvmdev" "$name"
done < <( grep -E "^done [^ ]+ lvmgrp" "$LAYOUT_TODO" )
