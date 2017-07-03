# dump-workflow.sh
#
# dump workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

LOCKLESS_WORKFLOWS=( ${LOCKLESS_WORKFLOWS[@]} dump )
WORKFLOW_dump_DESCRIPTION="dump configuration and system information"
WORKFLOWS=( ${WORKFLOWS[@]} dump )
WORKFLOW_dump () {
	LogPrint "Dumping out configuration and system information"

	if [ "$ARCH" != "$REAL_ARCH" ] ; then
		LogPrint "This is a '$REAL_ARCH' system, compatible with '$ARCH'."
	fi

	LogPrint "System definition:"
	for var in "ARCH" "OS" \
		"OS_MASTER_VENDOR" "OS_MASTER_VERSION" "OS_MASTER_VENDOR_ARCH" "OS_MASTER_VENDOR_VERSION" "OS_MASTER_VENDOR_VERSION_ARCH" \
		"OS_VENDOR" "OS_VERSION" "OS_VENDOR_ARCH" "OS_VENDOR_VERSION" "OS_VENDOR_VERSION_ARCH"; do
		LogPrint "$( printf "%40s = %s" "$var" "${!var}" )"
	done

	LogPrint "Configuration tree:"
	for config in "$ARCH" "$OS" \
		"$OS_MASTER_VENDOR" "$OS_MASTER_VENDOR_ARCH" "$OS_MASTER_VENDOR_VERSION" "$OS_MASTER_VENDOR_VERSION_ARCH" \
		"$OS_VENDOR" "$OS_VENDOR_ARCH" "$OS_VENDOR_VERSION" "$OS_VENDOR_VERSION_ARCH"; do
		if [ "$config" ] ; then
			LogPrint "$( printf "%40s : %s" "$config".conf "$(
									test -s $SHARE_DIR/conf/"$config".conf && echo OK || echo missing/empty
									)" )"
		fi
	done
	for config in site local ; do
		LogPrint "$( printf "%40s : %s" "$config".conf "$(
								test -s $CONFIG_DIR/"$config".conf && echo OK || echo missing/empty
								)" )"
	done

	LogPrint "Backup with $BACKUP"
	for opt in $(eval echo '${!'"$BACKUP"'_*}') ; do
		LogPrint "$( printf "%40s = %s" "$opt" "$(eval 'echo "${'"$opt"'[@]}"')" )"
	done
	for opt in $(eval echo '${!BACKUP_*}') ; do
		case $opt in
			BACKUP_PROG*) ;;
			*) LogPrint "$( printf "%40s = %s" "$opt" "$(eval 'echo "${'"$opt"'[@]}"')" )" ;;
		esac
	done

	case "$BACKUP" in
		NETFS)
		LogPrint "Backup program is '$BACKUP_PROG':"
		for opt in $(eval echo '${!BACKUP_PROG*}') ; do
			LogPrint "$( printf "%40s = %s" "$opt" "$(eval 'echo "${'"$opt"'[@]}"')" )"
		done
		;;
	esac

	LogPrint "Output to $OUTPUT"
	for opt in $(eval echo '${!'"$OUTPUT"'_*}' '${!OUTPUT_*}') RESULT_MAILTO ; do
		LogPrint "$( printf "%40s = %s" "$opt" "$(eval 'echo "${'"$opt"'[@]}"')" )"
	done

	Print ""

	UserOutput "$SHARE_DIR/lib/validated/$OS_VENDOR_VERSION_ARCH.txt"
	if test -s "$SHARE_DIR/lib/validated/$OS_VENDOR_VERSION_ARCH.txt" ; then
		LogPrint "Your system is validated with the following details:"
		while read -r ; do
			LogPrint "$REPLY"
		done <"$SHARE_DIR/lib/validated/$OS_VENDOR_VERSION_ARCH.txt"
	else
		LogPrint "Your system is not yet validated. Please carefully check all functions"
		LogPrint "and create a validation record with '$PROGRAM validate'. This will help others"
		LogPrint "to know about the validation status of $PRODUCT on this system."
		# if the master OS is validated print out a suitable hint
		if test -s "$SHARE_DIR/lib/validated/$OS_MASTER_VENDOR_VERSION_ARCH.txt" ; then
			LogPrint ""
			LogPrint "Your system is derived from $OS_MASTER_VENDOR_VERSION which is validated:"
			while read -r ; do
				LogPrint "$REPLY"
			done <"$SHARE_DIR/lib/validated/$OS_MASTER_VENDOR_VERSION_ARCH.txt"
		fi
	fi

}
