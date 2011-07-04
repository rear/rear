#
# some functions to create an email
#

# note: All functions use the SAME mime boundary !

MIME_BOUNDARY=_---------_-$RANDOM$RANDOM$RANDOM$RANDOM

#
# produce the headers of a mime/multipart message
#
# parameters:
# $1 = sender
# $2 = subject
# $3 $4 ... = recpients
#
function create_mime_mail_headers {
	from="$1" ; shift
	subject="$1" ; shift
	cat <<EOF
From: <$from>
$(for s in "$@" ; do echo "To: <$s>" ; done)
Date: $(date)
Content-Transfer-Encoding: 7bit
Content-Type: multipart/mixed; boundary="$MIME_BOUNDARY"
MIME-Version: 1.0
Subject: $subject

This is a multi-part message in MIME format.

EOF
}

#
# produce a text/plain mime part
#
# parameters:
# STDIN = mail body text
function create_mime_part_plain {
	echo "--$MIME_BOUNDARY"
	echo "Content-Transfer-Encoding: 7bit"
	echo "Content-Type: text/plain"
	echo
	cat
	echo
}

# produce an application/octet-stream mime part
#
# parameters
# $1 = file to attach
#
function create_mime_part_binary {
	echo "--$MIME_BOUNDARY"
	echo "Content-Transfer-Encoding: base64"
	echo "Content-Type: application/octet-stream; name=\"$(basename "$1")\""
	echo "Content-Disposition: attachment; filename=\"$(basename "$1")\""
	echo
	perl -MMIME::Base64 -0777 -ne 'print encode_base64($_)' <"$1"
	StopIfError "perl MIME::Base64 failed"
	echo
}

# at the end of each an every email one has to put the mime ending !
function create_mime_ending {
	echo "--$MIME_BOUNDARY--"
	echo
}
