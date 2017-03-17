
# Updating the currently running system.

# See https://github.com/rear/rear/issues/841

# Without a RECOVERY_UPDATE_URL there is nothing to do:
test "$RECOVERY_UPDATE_URL" || return

# With a RECOVERY_UPDATE_URL ensure 'curl' is actually there
# because that 'curl' was added to the default PROGS array
# (see https://github.com/rear/rear/issues/1156)
# is not sufficient to ensure 'curl' is actually there.
# This test is run in particular during "rear mkbackup/mkrescue"
# so that it errors out if 'curl' is required but not there:
has_binary curl || Error "RECOVERY_UPDATE_URL requires that 'curl' is installed"

# Currently updating ReaR is only supported during "rear recover"
# because "rear recover" is run first and only once in the recovery system
# (perhaps followed by several subsequent or simultaneous "rear restoreonly").
# Currently it is not tested what mess might happen for other workflows
# that run many times in one same system like "rear mkbackup" in the normal system.
# Furthermore it seems to make not much sense to update ReaR in the normal system
# via this special built-in ReaR functionality because in the normal system
# one can manually update ReaR as anything else.
test "$WORKFLOW" != "recover" && return

# The actual work:

# Tell the user that the recovery system will be updated:
LogPrint "Updating recovery system with the content from '$RECOVERY_UPDATE_URL':"

# Download the tar.gz that contains the update files.
local update_archive_filename="recovery-update.tar.gz"
# "curl -f" does not fail reliable (there are occasions where non-successful response codes will slip through)
# therefore the HTTP response code is written to stdout ('-w') so that it can be explicitly tested afterwards
# ('-s' does not show progress meter or error messages but 'S' it makes it show an error message if it fails)
# "curl --verbose" messages go to stderr so that they go to the "rear recover" log file:
local http_response_code=$( curl $verbose -f -s -S -w "%{http_code}" -o /$update_archive_filename $RECOVERY_UPDATE_URL )
# Only HTTP response code 200 "OK" is what we want (cf. https://en.wikipedia.org/wiki/List_of_HTTP_status_codes):
test "200" = "$http_response_code" || Error "curl '$RECOVERY_UPDATE_URL' failed with HTTP response code '$http_response_code'."

# Install the downloaded tar.gz at the root directory '/' of the recovery system-
# "tar --verbose" messages go to stdout so that they appear on the terminal where "rear recover" was started:
pushd /
tar $verbose -xf $update_archive_filename || Error "Updating recovery system via 'tar -xf /$update_archive_filename' failed."
popd

# Tell the user that recovery system update is done:
LogPrint "Updated recovery system."

