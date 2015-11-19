# some array functions

# return wether $1 equals one of the remaining arguments
function IsInArray() {
    local needle="$1"
    test -z "$needle" && return 1
    while shift ; do
        # at the end $1 becomes an unbound variable (after all arguments were shifted)
        # so that an empty default value is used to avoid 'set -eu' error exit
        # and that empty default value cannot match because needle is non-empty:
        test "$needle" == "${1:-}" && return 0
    done
    return 1
}

