# 400_copy_modules.sh
#
# Collect kernel modules and copy them into the rescue/recovery system.

# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# The special user setting MODULES=( 'no_modules' ) enforces that
# no kernel modules get included in the rescue/recovery system
# regardless of what modules are currently loaded.
# Test the first MODULES array element because other scripts
# in particular rescue/GNU/Linux/240_kernel_modules.sh
# already appended other modules to the MODULES array:
if test "no_modules" = "$MODULES" ; then
    LogPrint "Omit copying kernel modules (MODULES contains 'no_modules')"
    return
fi

# As general condition the /lib/modules/$KERNEL_VERSION directory must exist:
test "$KERNEL_VERSION" || KERNEL_VERSION="$( uname -r )"
if ! test -d "/lib/modules/$KERNEL_VERSION" ; then
    Error "Cannot copy kernel modules because /lib/modules/$KERNEL_VERSION does not exist"
fi

# Local functions that are 'unset' at the end of this script:
function modinfo_filename () {
    local module_name=$1
    local module_filename=""
    # Older modinfo (e.g. the one in SLES10) does not support '-k'
    # but that old modinfo returns a zero exit code when called as 'modinfo -k ...'
    # and shows a 'modinfo: invalid option -- k ...' message on stderr and nothing on stdout
    # so that we need to check if we got a non-empty module filename:
    module_filename=$( modinfo -k $KERNEL_VERSION -F filename $module_name )
    # If 'modinfo -k ...' stdout is empty we retry without '-k' regardless why stdout is empty
    # but then we do not discard stderr so that error messages appear in the log file.
    # In this case we must additionally ensure that KERNEL_VERSION matches 'uname -r'
    # otherwise a module file for a wrong kernel version would be found:
    if ! test $module_filename ; then
        test "$KERNEL_VERSION" = "$( uname -r )" || Error "modinfo_filename failed because KERNEL_VERSION does not match 'uname -r'"
        module_filename=$( modinfo -F filename $module_name )
    fi
    test $module_filename && echo $module_filename
}

# Artificial 'for' clause that is run only once
# to be able to 'continue' with the code after it
# when the kernel modules have been copied into the rescue/recovery system
# (the 'for' loop is run only once so that 'continue' is the same as 'break')
# which avoids dowdy looking code with deeply nested 'if...else' conditions:
for dummy in "once" ; do

    # The special user setting MODULES=( 'all_modules' ) enforces that
    # all files in the /lib/modules/$KERNEL_VERSION directory
    # get included in the rescue/recovery system.
    # Test all MODULES array members to make the 'all_modules' functionality work for
    # MODULES array contents like MODULES=( 'moduleX' 'all_modules' 'moduleY' ):
    if IsInArray "all_modules" "${MODULES[@]}" ; then
        LogPrint "Copying all kernel modules in /lib/modules/$KERNEL_VERSION (MODULES contains 'all_modules')"
        # The '--parents' is needed to get the '/lib/modules/' directory in the copy:
        if ! cp $verbose -t $ROOTFS_DIR -a --parents /lib/modules/$KERNEL_VERSION 1>&2 ; then
            Error "Failed to copy all kernel modules in /lib/modules/$KERNEL_VERSION"
        fi
        # After successful copying do the the code after the artificial 'for' clause:
        continue
    fi

    # The special user setting MODULES=( 'loaded_modules' ) enforces that
    # only those kernel modules that are currently loaded
    # get included in the rescue/recovery system.
    # Test all MODULES array members to make the 'loaded_modules' functionality work for
    # MODULES array contents like MODULES=( 'moduleX' 'loaded_modules' 'moduleY' ):
    if IsInArray "loaded_modules" "${MODULES[@]}" ; then
        LogPrint "Copying only currently loaded kernel modules (MODULES contains 'loaded_modules')"
        # The rescue/recovery system cannot work when its kernel modules
        # do not match the kernel that gets included in the rescue/recovery system
        # so that "rear mkrescue/mkbackup" errors out to be on the safe side
        # cf. https://github.com/rear/rear/wiki/Coding-Style
        # and https://github.com/rear/rear/wiki/Developers-Guide
        currently_running_kernel_version="$( uname -r )"
        if ! test "$KERNEL_VERSION" = "$currently_running_kernel_version" ; then
            Error "KERNEL_VERSION='$KERNEL_VERSION' does not match currently running kernel version ('uname -r' shows '$currently_running_kernel_version')"
        fi
        loaded_modules="$( lsmod | tail -n +2 | cut -d ' ' -f 1 )"
        # Can it really happen that a module is currently loaded but 'modinfo -F filename' cannot show its filename?
        # To be on the safe side there is a test even for for such a possibly weird error here:
        loaded_modules_files="$( for loaded_module in $loaded_modules ; do modinfo_filename $loaded_module || Error "$loaded_module loaded but no module file?" ; done )"
        # $loaded_modules_files cannot be empty because modinfo_filename fails when it cannot show a module filename:
        if ! cp $verbose -t $ROOTFS_DIR -L --preserve=all --parents $loaded_modules_files 1>&2 ; then
            Error "Failed to copy '$loaded_modules_files'"
        fi
        # After successful copying do the the code after the artificial 'for' clause:
        continue
    fi

    # Finally the default case:
    LogPrint "Copying kernel modules"
    for module in "${MODULES[@]}" ; do
        # Strip trailing ".o" if there:
        module=${module#.o}
        # Strip trailing ".ko" if there:
        module=${module#.ko}
        # Continue with the next module if the current one does not exist:
        modinfo $module 1>/dev/null || continue
        # Resolve module dependencies:
        # Get the module file plus the module files of other needed modules.
        # This is currently only a "best effort" attempt because
        # in general 'modprobe --show-depends' is insufficient to get all needed modules
        # see https://github.com/rear/rear/issues/1355
        # The --ignore-install is helpful because it converts currently unsupported '^install' output lines
        # into supported '^insmod' output lines for the particular module but that is also insufficient
        # see also https://github.com/rear/rear/issues/1355
        # The 'sort -u' removes duplicates only to avoid useless stderr warnings from the subsequent 'cp'
        # like "cp: warning: source file '/lib/modules/.../foo.ko' specified more than once"
        # regardless that nothing goes wrong when 'cp' gets duplicate source files
        # cf. http://blog.schlomo.schapiro.org/2015/04/warning-is-waste-of-my-time.html
        module_files=$( modprobe --ignore-install --set-version $KERNEL_VERSION --show-depends $module | awk '/^insmod / { print $2 }' | sort -u )
        if ! test "$module_files" ; then
            # Fallback is the plain module file without other needed modules (cf. the MODULES=( 'loaded_modules' ) case above):
            # Can it really happen that a module exists (which is tested above) but 'modinfo -F filename' cannot show its filename?
            # To be on the safe side there is a test even for for such a possibly weird error here:
            module_files="$( modinfo_filename $module || Error "$module exists but no module file?" )"
        fi
        # $module_files cannot be empty because modinfo_filename fails when it cannot show a module filename:
        if ! cp $verbose -t $ROOTFS_DIR -L --preserve=all --parents $module_files 1>&2 ; then
            Error "Failed to copy '$module_files'"
        fi
    done

# End of artificial 'for' clause:
done

# Remove those modules that are specified in the EXCLUDE_MODULES array:
for exclude_module in "${EXCLUDE_MODULES[@]}" ; do
    # Continue with the next module if the current one does not exist:
    modinfo $exclude_module 1>/dev/null || continue
    # In this case it is ignored when a module exists but 'modinfo -F filename' cannot show its filename
    # because then it is assumed that also no module file had been copied above:
    exclude_module_file="$( modinfo_filename $exclude_module )"
    test -e "$ROOTFS_DIR$exclude_module_file" && rm $verbose $ROOTFS_DIR$exclude_module_file 1>&2
done

# Generate modules.dep and map files that match the actually existing modules in the rescue/recovery system:
depmod -b "$ROOTFS_DIR" -v "$KERNEL_VERSION" 1>/dev/null || Error "depmod failed to configure modules for the rescue/recovery system"

# Generate /etc/modules for the rescue/recovery system:
recovery_system_etc_modules="$ROOTFS_DIR/etc/modules"
for module_to_be_loaded in "${MODULES_LOAD[@]}" ; do
    if ! grep -q "^$module_to_be_loaded\$" $recovery_system_etc_modules ; then
        # add module only if not exists to remove duplicates
        echo $module_to_be_loaded >>$recovery_system_etc_modules
    fi
done

# Local functions must be 'unset' because bash does not support 'local function ...'
# cf. https://unix.stackexchange.com/questions/104755/how-can-i-create-a-local-function-in-my-bashrc
unset -f modinfo_filename
