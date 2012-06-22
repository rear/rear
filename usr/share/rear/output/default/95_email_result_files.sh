#
# email all files specified in RESULT_FILES to RESULT_MAILTO
#

test -z "$RESULT_MAILTO" && return

[ ${#RESULT_FILES[@]} -gt 0 ]
StopIfError "No files to send (RESULT_FILES is empty)"

[ -x "$RESULT_SENDMAIL" ]
StopIfError "No mailer [$RESULT_SENDMAIL] found !"

Log "Sending Email from $RESULT_MAILFROM to ${RESULT_MAILTO[@]}"
Log "Attaching files: ${RESULT_FILES[@]}"

test -z "$RESULT_MAILSUBJECT" && RESULT_MAILSUBJECT="Relax-and-Recover $HOSTNAME ($OUTPUT)"

{
	create_mime_mail_headers "$RESULT_MAILFROM" \
		"$RESULT_MAILSUBJECT" \
		"${RESULT_MAILTO[@]}"

	echo -e "$VERSION_INFO\n\n" | cat - $CONFIG_DIR/templates/RESULT_m*ailbody.txt \
		$CONFIG_DIR/templates/RESULT_u*sage_$OUTPUT.txt | \
		create_mime_part_plain

	for file in "${RESULT_FILES[@]}" ; do
		create_mime_part_binary "$file"
	done

	create_mime_ending
} > $TMP_DIR/email.bin

MAIL_SIZE=( $(du -h $TMP_DIR/email.bin) )

LogPrint "Mailing resulting files ($MAIL_SIZE) to ${RESULT_MAILTO[@]}"
$RESULT_SENDMAIL "${RESULT_SENDMAIL_OPTIONS[@]}" <$TMP_DIR/email.bin
LogPrintIfError "WARNING ! Sending Email with '$RESULT_SENDMAIL "${RESULT_SENDMAIL_OPTIONS[@]}"' failed."
