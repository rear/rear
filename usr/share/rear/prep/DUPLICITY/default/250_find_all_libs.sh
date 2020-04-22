# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# 250_find_all_libs.sh 
# This is to find out missing libraries with strace.
# If strace isn't installed this script is skipped.
# TODO: I <jsmeix@suse.de> wonder if it is really needed
# to find out missing libraries here or if (and why)
# it isn't sufficient via the RequiredSharedObjects function
# that is called in build/GNU/Linux/390_copy_binaries_libraries.sh

# Check if Strace Readlink File Is available and Backup_PROG=Duply 
which strace || return 0
which readlink || return 0
which file || return 0
[ "x$BACKUP_PROG" == "xduply" ] || return 0

# Find Out the File used by duply status
FILES=$( strace -Ff -e open duply $DUPLY_PROFILE status 2>&1 1>/dev/null | grep -v '= -1' | grep -i open | grep -v "open resumed" | cut -d \" -f 2 | sort -u )

for name in $FILES ; do
    # Libs ar often Links, Solve the Links
    if [[ -f "$name" ]] || [[ -L "$name" ]] ; then
        DATEI=$( readlink -f "$name" )
        # Determinate if its a Lib
        LIB=$( file $DATEI | grep "shared object" | cut -d \: -f 1 )
        # Determinate if its a Script
        SKRIPT_FILES=$( file $DATEI | grep "script," | cut -d \: -f 1 )
        # Add the Lib
        [ "x$LIB" != "x" ] && LIBS+=( "$name" )
        # Add Script
        [ "x$SKRIPT_FILES" != "x" ] && COPY_AS_IS+=( "$SKRIPT_FILES" )
    fi
done
