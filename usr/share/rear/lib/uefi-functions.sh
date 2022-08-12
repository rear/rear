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
    # If GRUB2_MODULES_UEFI_LOAD is nonempty, it determines what modules to load
    local modules=( ${GRUB2_MODULES_UEFI_LOAD:+"${GRUB2_MODULES_UEFI_LOAD[@]}"} )

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
        # and output/USB/Linux-i386/100_create_efiboot.sh and output/default/940_grub2_rescue.sh
        # only if UEFI is used so that we simply error out here if we cannot make a bootable EFI image of GRUB2
        # (normally a function should not exit but return to its caller with a non-zero return code):
        Error "Cannot make bootable EFI image of GRUB2 (neither grub-mkstandalone nor grub2-mkstandalone found)"
    fi

    # Determine what modules need to be loaded in order to access given directories
    # (if the list of modules is not overriden by GRUB2_MODULES_UEFI_LOAD)
    if (( ${#dirs[@]} )) && ! (( ${#modules[@]} )) ; then
        if has_binary grub-probe ; then
            gprobe=grub-probe
        elif has_binary grub2-probe ; then
            # At least SUSE systems use 'grub2' prefixed names for GRUB2 programs:
            gprobe=grub2-probe
        else
            LogPrint "Neither grub-probe nor grub2-probe found"
            # Since openSUSE Leap 15.1 things were moved from /usr/lib/grub2/ to /usr/share/grub2/
            # cf. https://github.com/rear/rear/issues/2338#issuecomment-594432946
            if test /usr/*/grub*/x86_64-efi/partmap.lst ; then
                LogPrint "including all partition modules"
                modules=( $( cat /usr/*/grub*/x86_64-efi/partmap.lst ) )
            else
                Error "Can not determine partition modules, ${dirs[*]} would be likely inaccessible in GRUB2"
            fi
        fi

        if [ -n "$gprobe" ]; then
            # This is unfortunately only a crude approximation of the Grub internal probe_mods() function.
            # $gprobe --target=partmap "$p" | sed -e 's/^/part_/' does not always returns part_msdos
            # Therefore, we explicit do an echo 'part_msdos' (the sort -u will make sure it is listed only once)
            modules=( $( for p in "${dirs[@]}" ; do
                             $gprobe --target=fs "$p"
                             $gprobe --target=partmap "$p" | sed -e 's/^/part_/'
                             echo 'part_msdos'
                             $gprobe --target=abstraction "$p"
                         done | sort -u ) )
        fi
    fi

    # grub-mkstandalone needs a .../grub*/x86_64-efi/moddep.lst file (cf. https://github.com/rear/rear/issues/1193)
    # At least on SUSE systems that is in different 'grub2' directories (cf. https://github.com/rear/rear/issues/2338)
    # e.g. on openSUSE Leap 15.0 it is in /usr/lib/grub2/x86_64-efi/moddep.lst
    # but on openSUSE Leap 15.1 that was moved to /usr/share/grub2/x86_64-efi/moddep.lst
    # and the one in /boot/grub2/x86_64-efi/moddep.lst is a copy of the one in /usr/*/grub2/x86_64-efi/moddep.lst
    # so we do not error out if we do not find a /x86_64-efi/moddep.lst file because it could be "anywhere else" in the future
    # but we inform the user here in advance about possible problems when there is no /x86_64-efi/moddep.lst file.
    # Careful: usr/sbin/rear sets nullglob so that /usr/*/grub*/x86_64-efi/moddep.lst gets empty if nothing matches
    # and 'test -f' succeeds with empty argument so that we cannot use 'test -f /usr/*/grub*/x86_64-efi/moddep.lst'
    # also 'test -n' succeeds with empty argument but (fortunately/intentionally?) plain 'test' fails with empty argument.
    # Another implicit condition that this 'test' works is that '/usr/*/grub*/x86_64-efi/moddep.lst' matches at most one file
    # because otherwise e.g. "test /usr/*/grub*/x86_64-efi/mod*" where two files moddep.lst and modinfo.sh match
    # would falsely fail with "bash: test: ... unary operator expected":
    test /usr/*/grub*/x86_64-efi/moddep.lst || LogPrintError "$gmkstandalone may fail to make a bootable EFI image of GRUB2 (no /usr/*/grub*/x86_64-efi/moddep.lst file)"

    (( ${#GRUB2_MODULES_UEFI[@]} )) && LogPrint "Installing only ${GRUB2_MODULES_UEFI[*]} modules into $outfile memdisk"
    (( ${#modules[@]} )) && LogPrint "GRUB2 modules to load: ${modules[*]}"

    if ! $gmkstandalone $v ${GRUB2_MODULES_UEFI:+"--install-modules=${GRUB2_MODULES_UEFI[*]}"} ${modules:+"--modules=${modules[*]}"} -O x86_64-efi -o $outfile $embedded_config ; then
        Error "Failed to make bootable EFI image of GRUB2 (error during $gmkstandalone of $outfile)"
    fi
}

