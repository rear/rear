# 950_allow_missing_programs.sh
#
# Delete the programs can be skipped from the list of required programs

local option
for option in $( cat /proc/cmdline ); do
    if test "$option" = "cove_rescue_media" ; then
        return
    fi
done

if test "$WORKFLOW" != "shell" && test "$WORKFLOW" != "mksystemstate" ; then
    return
fi

local allowed_missed_progs=( bc chroot cmp diff dumpkeys file fuser join kbd_mode less loadkeys sync yes )

LogPrint "Before exclusion: REQUIRED_PROGS=(${REQUIRED_PROGS[*]})"
for prog in "${allowed_missed_progs[@]}"; do
    REQUIRED_PROGS=( $( RmInArray "$prog" "${REQUIRED_PROGS[@]}" ) )
done
LogPrint "After exclusion: REQUIRED_PROGS=(${REQUIRED_PROGS[*]})"
