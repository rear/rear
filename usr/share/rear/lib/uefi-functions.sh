function uefi_read_data {
    # input arg is path/data
    local dt
    dt=$(cat "$1" | hexdump -e '8/1 "%c""\n"' | tr -dc '[:print:]')
    echo $(trim $dt)
}

function uefi_read_attributes {
    # input arg is path/attributes
    local attr=""
    grep -q EFI_VARIABLE_NON_VOLATILE "$1" && attr="${attr}NV,"
    grep -q EFI_VARIABLE_BOOTSERVICE_ACCESS "$1" && attr="${attr}BS,"
    grep -q EFI_VARIABLE_RUNTIME_ACCESS "$1" && attr="${attr}RT"
    attr="(${attr})"
    echo "$attr"
}

function efibootmgr_read_var {
    # input args are $1 (efi var) and $2 (file $TMP_DIR/efibootmgr_output)
    local var
    var=$(grep "$1" $2 | cut -d: -f 2- | cut -d* -f2-)
    echo "$var"
}

function uefi_extract_bootloader {
    # input arg path/data
    local dt
    dt=$(cat "$1" | tail -1 | tr -cd '[:print:]\n' | cut -d\\ -f2-)
    echo "\\$(trim ${dt})"
}

function trim {
    local var="$1"
    var="${var#"${var%%[![:space:]]*}"}"   # remove leading whitespace characters
    var="${var%"${var##*[![:space:]]}"}"   # remove trailing whitespace characters
    echo -n "$var"
}

function build_bootx86_efi {
    local outfile="$1"
    local embedded_config=""
    local gmkstandalone=""
    local gprobe=""
    local dirs=()
    # modules is the list of modules to load
    # If GRUB2_MODULES is nonempty, it determines both what modules to install and to load
    local modules=( ${GRUB2_MODULES:+"${GRUB2_MODULES[@]}"} )

    # Configuration file is optional for image creation.
    shift
    if [[ -n "$1" ]] ; then
        # graft point syntax. $1 will appear as /boot/grub/grub.cfg in the image
        embedded_config="/boot/grub/grub.cfg=$1"
        shift
        # directories that should be accessible by GRUB2 (e.g. because they contain the kernel)
        dirs=( ${@:+"$@"} )
    fi

    if has_binary grub-mkstandalone ; then
        gmkstandalone=grub-mkstandalone
    elif has_binary grub2-mkstandalone ; then
        # At least SUSE systems use 'grub2' prefixed names for GRUB2 programs:
        gmkstandalone=grub2-mkstandalone
    else
        # This build_bootx86_efi function is only called in output/ISO/Linux-i386/250_populate_efibootimg.sh
        # which runs only if UEFI is used so that we simply error out here if we cannot make a bootable EFI image of GRUB2
        # (normally a function should not exit out but return to its caller with a non-zero return code):
        Error "Cannot make bootable EFI image of GRUB2 (neither grub-mkstandalone nor grub2-mkstandalone found)"
    fi

    # Determine what modules need to be loaded in order to access given directories
    # (if the list of modules is not overriden by GRUB2_MODULES)
    if (( ${#dirs[@]} )) && ! (( ${#modules[@]} )) ; then
        if has_binary grub-probe ; then
            gprobe=grub-probe
        elif has_binary grub2-probe ; then
            # At least SUSE systems use 'grub2' prefixed names for GRUB2 programs:
            gprobe=grub2-probe
        else
            LogWarn "Neither grub-probe nor grub2-probe found"
            if test /usr/lib/grub*/x86_64-efi/partmap.lst ; then
                LogWarn "including all partition modules"
                modules=( $(cat /usr/lib/grub*/x86_64-efi/partmap.lst) )
            else
                Error "Can not determine partition modules, ${dirs[*]} would be likely inaccessible in GRUB2"
            fi
        fi

        if [ -n "$gprobe" ]; then
            # this is unfortunately only a crude approximation of the Grub internal probe_mods() function
            modules=( $( for p in "${dirs[@]}" ; do
                             $gprobe --target=fs "$p"
                             $gprobe --target=partmap "$p" | sed -e 's/^/part_/'
                             $gprobe --target=abstraction "$p"
                         done | sort -u ) )
        fi
        Log "GRUB2 modules to load: ${modules:+${modules[*]}}"
    fi

    # grub-mkimage needs /usr/lib/grub/x86_64-efi/moddep.lst (cf. https://github.com/rear/rear/issues/1193)
    # and at least on SUSE systems grub2-mkimage needs /usr/lib/grub2/x86_64-efi/moddep.lst (in 'grub2' directory)
    # so that we error out if grub-mkimage or grub2-mkimage would fail when its moddep.lst is missing.
    # Careful: usr/sbin/rear sets nullglob so that /usr/lib/grub*/x86_64-efi/moddep.lst gets empty if nothing matches
    # and 'test -f' succeeds with empty argument so that we cannot use 'test -f /usr/lib/grub*/x86_64-efi/moddep.lst'
    # also 'test -n' succeeds with empty argument but (fortunately/intentionally?) plain 'test' fails with empty argument:
    test /usr/lib/grub*/x86_64-efi/moddep.lst || Error "$gmkstandalone would not make bootable EFI image of GRUB2 (no /usr/lib/grub*/x86_64-efi/moddep.lst file)"
    if ! $gmkstandalone $v ${GRUB2_MODULES:+"--install-modules=${GRUB2_MODULES[*]}"} ${modules:+"--modules=${modules[*]}"} -O x86_64-efi -o $outfile $embedded_config ; then
        Error "Failed to make bootable EFI image of GRUB2 (error during $gmkstandalone of $outfile)"
    fi
}

