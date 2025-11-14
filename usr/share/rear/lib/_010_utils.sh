#
# _010_utils.sh
#

# Utility functions for the basic ReaR framework
# Some functions were moved from _framework-setup-and-functions.sh
# in order to allow this script to be sourced in unit tests

# Check if any of the arguments is executable (logical OR condition).
# Using plain "type" without any option because has_binary is intended
# to know if there is a program that one can call regardless if it is
# an alias, builtin, function, or a disk file that would be executed
# see https://github.com/rear/rear/issues/729
function has_binary () {
    for bin in "$@" ; do
        # Suppress success output via stdout which is crucial when has_binary is called
        # in other functions that provide their intended function results via stdout
        # to not pollute intended function results with intermixed has_binary stdout
        # (e.g. the RequiredSharedObjects function) but keep failure output via stderr:
        type $bin 1>/dev/null && return 0
    done
    return 1
}
