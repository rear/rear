#
# output/default/950_copy_result_files.sh
# Copy the resulting files to the output location.
#

# For example for "rear mkbackuponly" there are usually no result files
# that would need to be copied here to the output location:
test "$RESULT_FILES" || return 0

local scheme=$( url_scheme $OUTPUT_URL )
local host=$( url_host $OUTPUT_URL )
local path=$( url_path $OUTPUT_URL )
local opath=$( output_path $scheme $path )

# if $opath is empty return silently (e.g. scheme tape)
if [[ -z "$opath" || -z "$OUTPUT_URL" || "$scheme" == "obdr" || "$scheme" == "tape" ]] ; then
    return 0
fi

LogPrint "Copying resulting files to $scheme location"

echo "$VERSION_INFO" >"$TMP_DIR/VERSION" || Error "Could not create $TMP_DIR/VERSION file"
RESULT_FILES+=( "$TMP_DIR/VERSION" )

local usage_readme_file=$( get_template "RESULT_usage_$OUTPUT.txt" )
if test -s $usage_readme_file ; then
    cp $v $usage_readme_file "$TMP_DIR/README" || Error "Could not copy $usage_readme_file to $TMP_DIR/README"
    RESULT_FILES+=( "$TMP_DIR/README" )
fi

# Usually RUNTIME_LOGFILE=/var/log/rear/rear-$HOSTNAME.log
# The RUNTIME_LOGFILE name is set by the main script from LOGFILE in default.conf
# but later user config files are sourced in the main script where LOGFILE can be set different
# so that the user config LOGFILE basename is used as final logfile name:
local final_logfile_name=$( basename $LOGFILE )
cat "$RUNTIME_LOGFILE" > "$TMP_DIR/$final_logfile_name" || Error "Could not copy $RUNTIME_LOGFILE to $TMP_DIR/$final_logfile_name"
RESULT_FILES+=( "$TMP_DIR/$final_logfile_name" )
LogPrint "Saving $RUNTIME_LOGFILE as $final_logfile_name to $scheme location"

# The real work (actually copying resulting files to the output location):
case "$scheme" in
    (nfs|cifs|usb|file|sshfs|ftpfs|davfs)
        LogPrint "Copying result files '${RESULT_FILES[@]}' to $opath at $scheme location"
        # Copy each result file one by one to avoid usually false error exits as in
        # https://github.com/rear/rear/issues/1711#issuecomment-380009044
        # where in case of an improper RESULT_FILES array member 'cp' can error out with something like
        #   cp: will not overwrite just-created '/tmp/rear.XXX/outputfs/f121/rear-f121.log' with '/tmp/rear.XXX/tmp/rear-f121.log'
        # See
        # https://stackoverflow.com/questions/4669420/have-you-ever-got-this-message-when-moving-a-file-mv-will-not-overwrite-just-c
        # which is about the same for 'mv', how to reproduce it:
        #   mkdir a b c
        #   touch a/f b/f
        #   mv a/f b/f c/
        #     mv: will not overwrite just-created 'c/f' with 'b/f'
        # It happens because two different files with the same name would be moved to the same place with only one command.
        # The -f option won't help for this case, it only applies when there already is a target file that will be overwritten.
        # Accordingly it is sufficient (even without '-f') to copy each result file one by one:
        for result_file in "${RESULT_FILES[@]}" ; do

            # note: s390 kernel copy is only through nfs
            #
            # s390 optional naming override of initrd and kernel to match the s390 filesytem naming conventions
            # on s390a there is an option to name the initrd and kernel in the form of
            # file name on s390 are in the form of name type mode
            # the name is the userid or vm name and the type is initrd or kernel
            # if the vm name (cp q userid) is HOSTA then the files written will be HOSTA kernel and HOSTA initrd
            # vars needed:
            # ZVM_NAMING      - set in local.conf, if Y then enable naming override
            # ZVM_KERNEL_NAME - keeps track of kernel name in results array
            # ARCH            - override only if ARCH is Linux-s390
            # 
            # initrd name override is handled in 900_create_initramfs.sh
            # kernel name override is handled in 400_guess_kernel.sh
            # kernel name override is handled in 950_copy_result_files.sh

            if [[ "$ZVM_NAMING" == "Y" && "$ARCH" == "Linux-s390" ]] ; then 
               if [[ -z $opath ]] ; then
                  Error "Output path is not set, please check OUTPUT_URL in local.conf."
               fi  

               if [ "$ZVM_KERNEL_NAME" == "$result_file" ] ; then
                  VM_UID=$(vmcp q userid |awk '{ print $1 }')

                  if [[ -z $VM_UID ]] ; then
                     Error "VM UID is not set, VM UID is set from call to vmcp.  Please make sure vmcp is available and 'vmcp q userid' returns VM ID"
                  fi      

                  LogPrint "s390 kernel naming override: $result_file will be written as $VM_UID.kernel"
                  cp $v "$result_file" $opath/$VM_UID.kernel || Error "Could not copy result file $result_file to $opath/$VM_UID.kernel at $scheme location"
               else
                  cp $v "$result_file" $opath/ || Error "Could not copy result file $result_file to $opath at $scheme location"
               fi
            else
               cp $v "$result_file" $opath/ || Error "Could not copy result file $result_file to $opath at $scheme location"
            fi
        done
        ;;
    (fish|ftp|ftps|hftp|http|https|sftp)
        # FIXME: Verify if usage of $array[*] instead of "${array[@]}" is actually intended here
        # see https://github.com/rear/rear/issues/1068
        LogPrint "Copying result files '${RESULT_FILES[*]}' to $scheme location"
        Log "lftp -c open $OUTPUT_URL; mput ${RESULT_FILES[*]}"
        lftp -c "open $OUTPUT_URL; mput ${RESULT_FILES[*]}" || Error "Problem transferring result files to $OUTPUT_URL"
        ;;
    (rsync)
        # If BACKUP = RSYNC output/RSYNC/default/900_copy_result_files.sh took care of it:
        test "$BACKUP" = "RSYNC" && return 0
        LogPrint "Copying result files '${RESULT_FILES[@]}' to $scheme location"
        Log "rsync -a $v ${RESULT_FILES[@]} ${host}:${path}"
        rsync -a $v "${RESULT_FILES[@]}" "${host}:${path}" || Error "Problem transferring result files to $OUTPUT_URL"
        ;;
    (*)
        Error "Invalid scheme '$scheme' in '$OUTPUT_URL'."
        ;;
esac

