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
LogUserOutput "Testing connection to TSM server"
dsmc query session 0<&6 1>&7 2>&8
local dsmc_exit_code=$?
# When 'dsmc query session' results a non-zero exit code inform the user but do not abort the whole "rear recover" here
# because it could be an unimportant reason why 'dsmc query session' finished with a non-zero exit code.
# What usual exit codes mean see http://publib.boulder.ibm.com/tividd/td/TSMC/GC32-0787-04/en_US/HTML/ans10000117.htm
# and see the code in usr/share/rear/restore/TSM/default/400_restore_with_tsm.sh
if test $dsmc_exit_code -eq 0 ; then
    LogUserOutput "Testing connection to TSM server completed successfully"
else
    LogUserOutput "Testing connection to TSM server completed with 'dsmc query session' exit code $dsmc_exit_code"
fi

