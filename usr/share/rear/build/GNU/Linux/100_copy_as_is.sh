# 400_copy_as_is.sh
#
# copy files and directories that should be copied over as-is to the rescue
# systems. Checks also for library dependencies of executables and adds
# them to the LIBS list, if they are not included in the copied files.

LogPrint "Copying files and directories"
Log "Files being copied: ${COPY_AS_IS[@]}"
Log "Files being excluded: ${COPY_AS_IS_EXCLUDE[@]}"

for f in "${COPY_AS_IS_EXCLUDE[@]}" ; do echo "$f" ; done >$TMP_DIR/copy-as-is-exclude
tar -v -X $TMP_DIR/copy-as-is-exclude \
	-P -C / -c "${COPY_AS_IS[@]}" 2>$TMP_DIR/copy-as-is-filelist | \
	tar $v -C $ROOTFS_DIR/ -x >/dev/null
StopIfError "Could not copy files and directories"
Log "Finished copying COPY_AS_IS"

# fix ReaR directory if running from checkout
if [[ "$REAR_DIR_PREFIX" ]] ; then
    for dir in /usr/share/rear /var/lib/rear ; do
        ln $v -sf $REAR_DIR_PREFIX$dir $ROOTFS_DIR$dir>/dev/null
    done
fi

### Copy configuration directory
mkdir $v -p $ROOTFS_DIR/etc/rear
# This will do same job as lines below.
# On top of that, it does not throw log warning like:
# "cp: missing destination file operand after"
# if hidden file (.<filename>) is missing in $CONFIG_DIR
cp $v -r $CONFIG_DIR/. $ROOTFS_DIR/etc/rear/ >&2

COPY_AS_IS_EXELIST=()
while read -r ; do
	if [[ ! -d "$REPLY" && -x "$REPLY" ]]; then
		COPY_AS_IS_EXELIST=( "${COPY_AS_IS_EXELIST[@]}" "$REPLY" )
	fi
done <$TMP_DIR/copy-as-is-filelist
Log "COPY_AS_IS_EXELIST = ${COPY_AS_IS_EXELIST[@]}"

Log "Adding required libraries to LIBS with checking COPY_AS_IS_EXELIST"
# add required libraries to LIBS, skip libraries that are part of the copied files.
while read -r ; do
	lib="$REPLY"
	if ! IsInArray "$lib" "${COPY_AS_IS_EXELIST[@]}"; then
		# if $lib is NOT part of the copy-as-is fileset, then add it to the global libs
		LIBS=( ${LIBS[@]} $lib )
	else
		Log "Not adding $lib to LIBS because it is already in COPY_AS_IS_EXELIST"
	fi
done < <( SharedObjectFiles "${COPY_AS_IS_EXELIST[@]}" | sed -e 's#^#/#' )
Log "LIBS = ${LIBS[@]}"

