# 950_nsr_save_result_files.sh
# saving result files via NSR

# In case NSR_CLIENT_MODE is enabled return else continue ...
if is_true "$NSR_CLIENT_MODE"; then
    return
fi

test ${#RESULT_FILES[@]} -gt 0 || Error "No files to copy (RESULT_FILES is empty)"

LogPrint "Saving result files with NSR (EMC NetWorker)"
NSR_RESULT_FILES=()

# decide where to put the result files for saving them with NSR
# if NSR_RESULT_FILE_PATH is unset, then save the result files where they are
# NOTE: Make sure that your NSR installation will not silently skip files in $TMP_DIR !
test -z "$NSR_RESULT_FILE_PATH" && NSR_RESULT_FILE_PATH=$TMP_DIR

if ! test -d "$NSR_RESULT_FILE_PATH" ; then
	 mkdir -v -p "$NSR_RESULT_FILE_PATH" 1>/dev/null
	 StopIfError "Could not create '$NSR_RESULT_FILE_PATH'"
fi


if test "$NSR_RESULT_FILE_PATH" != "$TMP_DIR" ; then
	cp -v  "${RESULT_FILES[@]}" "$NSR_RESULT_FILE_PATH" 1>/dev/null
	StopIfError "Could not copy result files to '$NSR_RESULT_FILE_PATH'"
	NSR_RESULT_FILES=( 
		$(
			for fname in "${RESULT_FILES[@]}" ; do 
				echo "$NSR_RESULT_FILE_PATH/$(basename "$fname")"
			done
		 )
	)
else
	NSR_RESULT_FILES=( "${RESULT_FILES[@]}" )
fi

if test -s "$CONFIG_DIR/templates/RESULT_usage_$OUTPUT.txt" ; then
	cp -v $CONFIG_DIR/templates/RESULT_usage_$OUTPUT.txt "$NSR_RESULT_FILE_PATH/README" 1>/dev/null
	StopIfError "Could not copy '$CONFIG_DIR/templates/RESULT_usage_$OUTPUT.txt'"
	NSR_RESULT_FILES+=( "$NSR_RESULT_FILE_PATH"/README )
fi

NSRSERVER=$(cat $VAR_DIR/recovery/nsr_server )
CLIENTNAME=$(hostname)
#POOLNAME="$( mminfo -s $NSRSERVER -a -q "client=$CLIENTNAME" -r "pool" | head -1 )"
if [[ -z "$NSR_POOL_NAME" ]] ; then
    POOLNAME="$( mminfo -ot -s $NSRSERVER -a -q "client=$CLIENTNAME,name=/" -r "avail,pool" | \
        awk '$1 ~ "n" { print $2; exit; }' )"
else
    POOLNAME="$NSR_POOL_NAME"
fi
[[ -z "$POOLNAME" ]] && POOLNAME="$NSR_DEFAULT_POOL_NAME"
[[ -z "$NSR_RETENTION_TIME" ]] && NSR_RETENTION_TIME="1 day"

Log "Saving files '${NSR_RESULT_FILES[@]}' with save"
SNAME="REAR.$(date +%Y%m%d)"
save -s $NSRSERVER -c $CLIENTNAME -N "${SNAME}" -b "$POOLNAME" -y "$NSR_RETENTION_TIME" "${NSR_RESULT_FILES[@]}" 1>/dev/null
StopIfError "Could not save result files with save"

# show the saved result files
LogPrint "If the NSR_RETENTION_TIME=\"$NSR_RETENTION_TIME\" is too low please add NSR_RETENTION_TIME variable in $CONFIG_DIR/local.conf"
LogPrint " pool           retent  name"
LogPrint "============================"
#mminfo -s $NSRSERVER -a -q "client=$CLIENTNAME" -r "pool,ssretent,name" | \
#    grep -E $( echo ${NSR_RESULT_FILES[@]} | sed -e "s/ /|/g") > $TMP_DIR/saved_result_files
mminfo -s $NSRSERVER -a -q "client=$CLIENTNAME,name=${SNAME},pool=${POOLNAME}" \
    -r "pool,ssretent,name" > $TMP_DIR/saved_result_files
LogPrint "$(cat $TMP_DIR/saved_result_files)"
