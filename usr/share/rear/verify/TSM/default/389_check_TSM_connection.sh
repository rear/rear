# Test connection to the TSM server.
#
# Additionally this requests a general TSM password from the user
# when there is no TSM password file 'TSM.PWD' in the recovery system
# cf. https://github.com/rear/rear/issues/1642
# but it does not request possibly further TSM passwords from the user
# like passwords for encryption or decryption of files, cf.
# https://github.com/rear/rear/issues/1534#issuecomment-351313623
#
# Regarding usage of '0<&6 1>&7 2>&8' see
# "What to do with stdin, stdout, and stderr"
# in https://github.com/rear/rear/wiki/Coding-Style
#
# Test with "dsmc query session" (it is faster than e.g. "dsmc query mgmt")
# and it is also enough for the prompt of the general TSM password, cf.
# https://github.com/rear/rear/issues/1534#issuecomment-351067465
dsmc query session 0<&6 1>&7 2>&8 && return
Error "No connection to TSM server ('dsmc query session' returns '$?')"

