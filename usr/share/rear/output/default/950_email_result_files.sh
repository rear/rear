#
# email all files specified in RESULT_FILES to RESULT_MAILTO
#

test -z "$RESULT_MAILTO" && return

[ ${#RESULT_FILES[@]} -gt 0 ] || Error "No files to send (RESULT_FILES is empty)"

[ -x "$RESULT_SENDMAIL" ] || Error "No mailer [$RESULT_SENDMAIL] found !"

Log "Sending e-mail from $RESULT_MAILFROM to ${RESULT_MAILTO[*]}"

# We will remove the ISO files from the RESULT_FILES array (is becoming too big - issue #397)
c=${#RESULT_FILES[@]} # amount of element is array RESULT_FILES
i=0
while (( $i < $c )) ; do
    echo ${RESULT_FILES[i]} | grep -q "\.iso$" || MAIL_FILES+=( ${RESULT_FILES[i]} )
    i=$(( i + 1 ))
done
 
Log "Attaching files: ${MAIL_FILES[*]}"

test -z "$RESULT_MAILSUBJECT" && RESULT_MAILSUBJECT="Relax-and-Recover $HOSTNAME ($OUTPUT)"

{
	create_mime_mail_headers "$RESULT_MAILFROM" \
		"$RESULT_MAILSUBJECT" \
		"${RESULT_MAILTO[@]}"

	echo -e "$VERSION_INFO\n\n" | cat - $(get_template "RESULT_m*ailbody.txt") \
		$(get_template "RESULT_u*sage_$OUTPUT.txt") | \
		create_mime_part_plain

	for file in "${MAIL_FILES[@]}" ; do
		create_mime_part_binary "$file"
	done

	create_mime_ending
} > $TMP_DIR/email.bin

MAIL_SIZE=( $(du -h $TMP_DIR/email.bin) )

LogPrint "Mailing resulting files ($MAIL_SIZE) to ${RESULT_MAILTO[*]}"
if ! $RESULT_SENDMAIL "${RESULT_SENDMAIL_OPTIONS[@]}" <$TMP_DIR/email.bin ; then
    LogPrintError "WARNING: Sending e-mail with '$RESULT_SENDMAIL ${RESULT_SENDMAIL_OPTIONS[*]}' failed"
fi
