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
    # 'modprobe -n -R' prints all module names matching an alias so we have its output in an array
    # and use only its first element to consider only the first printed module name:
    local alias_module_name=( $( modprobe -n -R $module_name 2>/dev/null ) )
    # If the installed modprobe command supports resolving module aliases (-R), use that capability.
    test $alias_module_name && module_name=$alias_module_name
    # Older modinfo (e.g. the one in SLES10) does not support '-k'
    # but that old modinfo returns a zero exit code when called as 'modinfo -k ...'
    # and shows a 'modinfo: invalid option -- k ...' message on stderr and nothing on stdout
    # so that we need to check if we got a non-empty module filename.
    # Older modinfo (in particular modinfo before kmod-27 since SLES15-SP3)
    # outputs nothing on stdout for builtin kernel "modules" and exits with exit code 1 like
    #   # modinfo -F filename unix
    #   modinfo: ERROR: Module unix not found.
    # Newer modinfo (in particular modinfo in kmod-27 since SLES15-SP3)
    # outputs on stdout for builtin kernel "modules" and exits with zero exit code like
    #   # modinfo -F filename unix
    #   name:           unix
    #   (builtin)
    # For real kernel modules the modinfo stdout is one word that is the kernel module filename like
    #   # modinfo -F filename sg
    #   /lib/modules/5.3.18-43-default/kernel/drivers/scsi/sg.ko.xz
    module_filename="$( modinfo -k $KERNEL_VERSION -F filename $module_name )"
    # If 'modinfo -k ...' stdout is empty we retry without '-k' regardless why stdout is empty
    # but then we do not discard stderr so that error messages appear in the log file.
    # In this case we must additionally ensure that KERNEL_VERSION matches 'uname -r'
    # otherwise a module file for a wrong kernel version would be found:
    if ! test "$module_filename" ; then
        test "$KERNEL_VERSION" = "$( uname -r )" || Error "modinfo_filename failed because KERNEL_VERSION does not match 'uname -r'"
        module_filename="$( modinfo -F filename $module_name )"
    fi
    # grep for '(builtin)' in the modinfo stdout to get the builtin kernel "module" case
    grep -q '(builtin)' <<<"$module_filename" && return
    # Let modinfo_filename return the exit code of 'readlink -e $module_filename'
    # 'readlink -e something' shows the filename when something is one or more files and exits with zero exit code
    # 'readlink -e something' shows the symlink target when something is a symlink and exits with zero exit code
    # 'readlink -e something' shows nothing when something is no file or a broken symlink and exits with exit code 1
    # 'readlink -e something' shows nothing on stdout but an error on stderr when something is empty and exits with exit code 1
    # It is crucial to output the original module_filename also when it is a symlink
    # because in the code below 'cp -L' copies the symlink taget content
    # as a new regular file with file name as the name of the symlink
    # so the copied content can be still found under its original name,
    # cf. https://github.com/rear/rear/issues/2677#issuecomment-997859219
    readlink -e $module_filename 1>/dev/null && echo "$module_filename"
}

# Artificial 'for' clause that is run only once
# to be able to 'continue' with the code after it
# when the kernel modules have been copied into the rescue/recovery system
# (the 'for' loop is run only once so that 'continue' is the same as 'break')
# which avoids dowdy looking code with deeply nested 'if...else' conditions:
for dummy in "once" ; do

    # Since ReaR version 2.5 we have MODULES=( 'all_modules' ) in default.conf
    # see https://github.com/rear/rear/issues/2041
    # which results that all files in the /lib/modules/$KERNEL_VERSION
    # directory get included in the recovery system.
    # Test all MODULES array members to make the 'all_modules' functionality work for
    # MODULES array contents like MODULES=( 'moduleX' 'all_modules' 'moduleY' ):
    if IsInArray "all_modules" "${MODULES[@]}" ; then
        LogPrint "Copying all kernel modules in /lib/modules/$KERNEL_VERSION (MODULES contains 'all_modules')"
        # The '--parents' is needed to get the '/lib/modules/' directory in the copy.
        # The '-L' copies the actual content to avoid dangling symlinks in the recovery system
        # cf. https://github.com/rear/rear/issues/2677#issuecomment-997859219
        # It is crucial to append to /dev/$DISPENSABLE_OUTPUT_DEV (cf. 'Print' in lib/_input-output-functions.sh):
        if ! cp $verbose -t $ROOTFS_DIR -a -L --parents /lib/modules/$KERNEL_VERSION 2>>/dev/$DISPENSABLE_OUTPUT_DEV 1>&2 ; then
            # Do not error out if 'cp -a -L' failed to to copy all contents of /lib/modules/$KERNEL_VERSION
            # because dangling symlinks let 'cp -L' fail and there is no cp option to let it skip broken symlinks
            # and then the cp exit code is 1 so it cannot be used to distinguish this case from other errors
            # see https://github.com/rear/rear/issues/2739#issuecomment-1012949307
            # but dangling symlinks in /lib/modules/$KERNEL_VERSION are usually harmless
            # so we do not want to error out because of dangling symlinks
            # and only tell the user about the issue so he could inspect his system and decide
            # see https://github.com/rear/rear/issues/2739#issuecomment-1014304127
            LogPrintError "Failed to copy all contents of /lib/modules/$KERNEL_VERSION (dangling symlinks could be a reason)"
        fi
        # After successful copying do the the code after the artificial 'for' clause:
        continue
    fi

    # The setting MODULES=( 'loaded_modules' ) results that only those kernel modules
    # that are currently loaded get included in the recovery system.
    # Test all MODULES array members to make the 'loaded_modules' functionality work for
    # MODULES array contents like MODULES=( 'moduleX' 'loaded_modules' 'moduleY' ):
    if IsInArray "loaded_modules" "${MODULES[@]}" ; then
        # Kernel modules that should be loaded during recovery system startup must be always copied into the recovery system:
        LogPrint "Copying only currently loaded kernel modules (MODULES contains 'loaded_modules') and those in MODULES_LOAD"
        # The rescue/recovery system cannot work when its kernel modules
        # do not match the kernel that gets included in the rescue/recovery system
        # so that "rear mkrescue/mkbackup" errors out to be on the safe side
        # cf. https://github.com/rear/rear/wiki/Coding-Style
        # and https://github.com/rear/rear/wiki/Developers-Guide
        currently_running_kernel_version="$( uname -r )"
        if ! test "$KERNEL_VERSION" = "$currently_running_kernel_version" ; then
            Error "KERNEL_VERSION='$KERNEL_VERSION' does not match currently running kernel version ('uname -r' shows '$currently_running_kernel_version')"
        fi
        # Kernel modules that should be loaded during recovery system startup must be always copied into the recovery system:
        loaded_modules="${MODULES_LOAD[@]}"
        # The leading blank before $(...) is mandatory (otherwise the last in MODULES_LOAD is concatenated with the first of lsmod):
        loaded_modules+=" $( lsmod | tail -n +2 | cut -d ' ' -f 1 )"
        # It can happen that a module is loaded or should be loaded but 'modinfo -F filename' cannot show its filename
        # when it is loaded or should be loaded under a module alias name but the above modinfo_filename function
        # could not resolve aliases (when the modprobe command does not support -R).
        # The 'sort -u' removes duplicates only to avoid useless stderr warnings from the subsequent 'cp'
        # like "cp: warning: source file '/lib/modules/.../foo.ko' specified more than once"
        # regardless that nothing goes wrong when 'cp' gets duplicate source files
        # cf. http://blog.schlomo.schapiro.org/2015/04/warning-is-waste-of-my-time.html
        loaded_modules_files="$( for loaded_module in $loaded_modules ; do modinfo_filename $loaded_module || Error "$loaded_module loaded or to be loaded but no module file?" ; done | sort -u )"
        # $loaded_modules_files could be empty as extreme case because modinfo_filename outputs nothing in the builtin kernel "module" case:
        test "$loaded_modules_files" || continue
        if ! cp $verbose -t $ROOTFS_DIR -L --preserve=all --parents $loaded_modules_files 1>&2 ; then
            Error "Failed to copy '$loaded_modules_files'"
        fi
        # After successful copying do the the code after the artificial 'for' clause:
        continue
    fi

    # Finally the fallback cases, i.e. when the user has specified
    # MODULES=() which means the currently loaded kernel modules get included in the recovery system
    # plus the modules that get added above plus kernel modules for certain kernel drivers like
    # storage drivers, network drivers, crypto drivers, virtualization drivers, and some extra drivers
    # (see rescue/GNU/Linux/230_storage_and_network_modules.sh
    #  and rescue/GNU/Linux/240_kernel_modules.sh)
    # or when the user has specified
    # MODULES=( 'moduleX' 'moduleY' ) where additional kernel modules can be specified
    # to be included in the recovery system in addition to the ones via an empty MODULES=() setting:
    LogPrint "Copying kernel modules as specified by MODULES"
    # Before ReaR version 2.5 the below added modules had been added via conf/GNU/Linux.conf
    # which is sourced in usr/sbin/rear before user config files like etc/rear/local.conf
    # so that the user had to specify MODULES+=( 'moduleX' 'moduleY' )
    # to not lose the below added modules but with MODULES=( 'all_modules' ) in default.conf
    # this would keep the 'all_modules' default value in any case in the MODULES array
    # which would trigger the above 'all_modules' case in any case.
    # As a way out of this dilemma we add the below listed modules no longer via conf/GNU/Linux.conf
    # but here after the user config files were sourced so that now the user can specify
    # MODULES=( 'moduleX' 'moduleY' ) in etc/rear/local.conf to get additional kernel modules
    # included in the recovery system in addition to the ones via an empty MODULES=() setting.
    # nvram could be a module in particular on POWER architecture,
    # cf. https://github.com/rear/rear/issues/2554#issuecomment-764720180
    # and https://github.com/rear/rear/pull/2580#issuecomment-791344794
    MODULES+=( nvram
               vfat
               nls_iso8859_1 nls_utf8 nls_cp437
               af_packet
               unix
               nfs nfsv4 nfsv3 lockd sunrpc
               cifs
               usbcore usb_storage usbhid uhci_hcd ehci_hcd xhci_hcd ohci_hcd
               sr_mod ide_cd cdrom
               zlib zlib-inflate zlib-deflate
               libcrc32c crc32c crc32c-intel )
    # Include the modules in MODULES plus their dependant modules.
    # Kernel modules that should be loaded during recovery system startup must be always copied into the recovery system:
    for module in "${MODULES_LOAD[@]}" "${MODULES[@]}" ; do
        # Strip trailing ".o" if there:
        module=${module#.o}
        # Strip trailing ".ko" if there:
        module=${module#.ko}
        # Continue with the next module if the current one does not exist as a module file:
        modinfo $module 1>/dev/null || continue
        # Continue with the next module if the current one is a kernel builtin module
        # cf. https://github.com/rear/rear/issues/2414#issuecomment-668632798
        # Quoting the grep search value is mandatory here ($module might be empty or blank),
        # cf. "Beware of the emptiness" in https://github.com/rear/rear/wiki/Coding-Style
        grep -q "$( echo $module | tr '_-' '..' )" /lib/modules/$KERNEL_VERSION/modules.builtin && continue
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
            # It can happen that 'modinfo -F filename' cannot show the module filename
            # when it is specified under a module alias name but the above modinfo_filename function
            # could not resolve aliases (when the modprobe command does not support -R):
            module_files="$( modinfo_filename $module || Error "$module exists but no module file?" )"
        fi
        # $module_files can be empty because modinfo_filename outputs nothing in the builtin kernel "module" case:
        test "$module_files" || continue
        if ! cp $verbose -t $ROOTFS_DIR -L --preserve=all --parents $module_files 1>&2 ; then
            Error "Failed to copy '$module_files'"
        fi
    done

# End of artificial 'for' clause:
done

# Remove those modules that are specified in the EXCLUDE_MODULES array:
for exclude_module in "${EXCLUDE_MODULES[@]}" ; do
    # Continue with the next module only if the current one does not exist as a module file
    # but do not continue with the next module if the current one is a kernel builtin module
    # so when a module file exists that gets removed regardless if it is also a builtin module
    # cf. https://github.com/rear/rear/issues/2414#issuecomment-669115481
    modinfo $exclude_module 1>/dev/null || continue
    # In this case it is ignored when a module exists but 'modinfo -F filename' cannot show its filename
    # because then it is assumed that also no module file had been copied above:
    exclude_module_file="$( modinfo_filename $exclude_module )"
    test -e "$ROOTFS_DIR$exclude_module_file" && rm $verbose $ROOTFS_DIR$exclude_module_file 1>&2
done

# Generate modules.dep and map files that match the actually existing modules in the rescue/recovery system:
depmod -b "$ROOTFS_DIR" -v "$KERNEL_VERSION" 1>/dev/null || Error "depmod failed to configure modules for the rescue/recovery system"

# Generate /etc/modules for the rescue/recovery system.
# We use a little trick here. In COPY_AS_IS we also include /etc/modules and COPY_AS_IS is copied BEFORE
# this script. So here we already might have the original /etc/modules of the source system which is why
# we only append lines. That way the original module order AND module parameters are preserved

# We first append the initrd modules file for Debian before adding the modules that
# we collected from various sources in the MODULES_LOAD array, e.g. in 220_load_modules_from_initrd.sh
recovery_system_etc_modules="$ROOTFS_DIR/etc/modules"
if test -s /etc/initramfs-tools/modules ; then
    cat </etc/initramfs-tools/modules >>$recovery_system_etc_modules
fi

# Finally append MODULES_LOAD
for module_to_be_loaded in "${MODULES_LOAD[@]}" ; do
    if ! grep -E -q "^$module_to_be_loaded(\s|\$)" $recovery_system_etc_modules ; then
        # add module only if not exists to remove duplicates
        echo $module_to_be_loaded >>$recovery_system_etc_modules
    fi
done

# Local functions must be 'unset' because bash does not support 'local function ...'
# cf. https://unix.stackexchange.com/questions/104755/how-can-i-create-a-local-function-in-my-bashrc
unset -f modinfo_filename

