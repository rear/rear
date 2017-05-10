# 400_copy_modules.sh
#
# Copy kernel modules to the rescue/recovery system.

#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# The special value MODULES=( 'none' ) enforces that
# no kernel modules get included in the rescue/recovery system
# regardless of what modules are currently loaded.
# Test the first MODULES array element because other scripts
# in particular rescue/GNU/Linux/240_kernel_modules.sh
# already appended other modules to the MODULES array:
if test "none" = "$MODULES" ; then
    LogPrint "Omit copying kernel modules (MODULES contains 'none')"
    return
fi

# Artificial 'for' clause that is run only once
# to be able to 'continue' with the code after it
# when the kernel modules have been copied into the rescue/recovery system
# (the 'for' loop is run only once so that 'continue' is the same as 'break')
# which avoids dowdy looking code with deeply nested 'if...else' conditions:
for dummy in "once" ; do

    # The special user setting MODULES=( 'all' ) enforces that
    # all files from the /lib/modules/* directories
    # get included in the rescue/recovery system
    # regardless of what is set in EXCLUDE_MODULES.
    # Test all MODULES array members to make the 'all' functionality work for
    # MODULES array contents like MODULES=( 'moduleX' 'all' 'moduleY' ):
    if IsInArray "all" "${MODULES[@]}" ; then
        LogPrint "Copying all kernel modules in /lib/modules/* (MODULES contains 'all')"
        # The '--parents' is needed to get the '/lib/' directory in the copy:
        if ! cp $verbose -t $ROOTFS_DIR -a --parents /lib/modules 1>&2 ; then
            Error "Failed to copy all kernel modules in /lib/modules/*"
        fi
        # After successful copying do the the code after the artificial 'for' clause:
        continue
    fi

    # The special user setting MODULES=( 'loaded' ) enforces that
    # exactly those kernel modules get included in the rescue/recovery system
    # that are currently loaded regardless of what is set in EXCLUDE_MODULES
    # and regardless of what rescue/GNU/Linux/240_kernel_modules.sh has added.
    # Test all MODULES array members to make the 'loaded' functionality work for
    # MODULES array contents like MODULES=( 'moduleX' 'all' 'moduleY' ):
    if IsInArray "loaded" "${MODULES[@]}" ; then
        LogPrint "Copying only currently loaded kernel modules (MODULES contains 'loaded')"
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
        loaded_modules_files="$( for loaded_module in $loaded_modules ; do modinfo -F filename $loaded_module || Error "$loaded_module loaded but no module file?" ; done )"
        for loaded_module_file in $loaded_modules_files ; do
            if ! cp $verbose -t $ROOTFS_DIR -L --preserve=all --parents $loaded_module_file 1>&2 ; then
                Error "Failed to copy $loaded_module_file"
            fi
        done
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
        # Check if the module is not in the exclude list:
        for exclude_module in "${EXCLUDE_MODULES[@]}" ; do
            # Continue with the next module if the current one is in EXCLUDE_MODULES:
            test "$module" = "$exclude_module" && continue 2
        done
        # Continue with the next module if the current one does not exist:
        modinfo $module &>/dev/null || continue
        # Use /etc/modprobe.conf if exists:
        with_modprobe_conf=""
        test -e /etc/modprobe.conf && with_modprobe_conf="-C /etc/modprobe.conf"
        # Resolve module dependencies:
        # I.e. get the module file plus the module files of other needed modules.
        # This is currently only a "best effort" attempt because
        # in general 'modprobe --show-depends' insufficient to get all needed modules
        # see https://github.com/rear/rear/issues/1355
        # The --ignore-install is helpful because that converts currently unsupported '^install' output lines
        # into supported '^insmod' output lines for the particular module but that is also insufficient
        # see also https://github.com/rear/rear/issues/1355
        module_files=$( /sbin/modprobe $with_modprobe_conf --ignore-install --set-version $KERNEL_VERSION --show-depends $module 2>/dev/null | awk '/^insmod / { print $2 }' )
        if ! test "$module_files" ; then
            # Fallback is the plain module file without other needed modules (cf. the MODULES=( 'loaded' ) case above):
            # Can it really happen that a module exists (which is tested above) but 'modinfo -F filename' cannot show its filename?
            # To be on the safe side there is a test even for for such a possibly weird error here:
            module_files="$( modinfo -F filename $module || Error "$module exists but no module file?" )"
        fi
        for module_file in $module_files ; do
            if ! cp $verbose -t $ROOTFS_DIR -L --preserve=all --parents $module_file 1>&2 ; then
                Error "Failed to copy $module_file"
            fi
        done
    done

done

# Generate modules.dep and map files in all existing $ROOTFS_DIR/lib/modules/* directories
# (because of the MODULES=( 'all' ) case several such directories could exist):
for kernel_version in $( ls $ROOTFS_DIR/lib/modules/ ) ; do
    if test -d $ROOTFS_DIR/lib/modules/$kernel_version ; then
        depmod -b "$ROOTFS_DIR" -v "$kernel_version" >/dev/null || Error "depmod failed to configure modules for the rescue/recovery system"
    fi
done

recovery_system_etc_modules="$ROOTFS_DIR/etc/modules"
for module_to_be_loaded in "${MODULES_LOAD[@]}" ; do
    echo $module_to_be_loaded
done >>$recovery_system_etc_modules
# remove duplicates:
cat $recovery_system_etc_modules | sort -u > $recovery_system_etc_modules.new
mv -f $recovery_system_etc_modules.new $recovery_system_etc_modules

