# Test connection to the TSM server.
#
# TODO: This should be enhanced to request a TSM password from the user
# when there is no TSM password file 'TSM.PWD' in the recovery system
# cf. https://github.com/rear/rear/issues/1642
#
# Regarding usage of '0<&6 1>&7 2>&8' see
# "What to do with stdin, stdout, and stderr"
# in https://github.com/rear/rear/wiki/Coding-Style
#
# First try "dsmc query session" because it is faster than "dsmc query mgmt":
dsmc query session 0<&6 1>&7 2>&8 && return
LogPrintError "Possibly no connection to TSM server ('dsmc query session' returns '$?')"
# When "dsmc query session" failed try "dsmc query mgmt":
dsmc query mgmt 0<&6 1>&7 2>&8 && return
Error "No connection to TSM server ('dsmc query mgmt' returns '$?')"

