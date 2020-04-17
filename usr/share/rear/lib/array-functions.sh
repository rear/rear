# some array functions

# return whether $1 equals one of the remaining arguments
function IsInArray() {
    { local needle="$1"
      test -z "$needle" && return 1
      while shift ; do
          # at the end $1 becomes an unbound variable (after all arguments were shifted)
          # so that an empty default value is used to avoid 'set -eu' error exit
          # and that empty default value cannot match because needle is non-empty:
          test "$needle" == "${1:-}" && return 0
      done
    } 2>>/dev/$DISPENSABLE_OUTPUT_DEV
    return 1
}

function RmInArray() {
    # "$1" string to be removed in array "${2[@]}"
    # please note that the array elements are a bunch of words in this function
    # usage: BACKUP_RSYNC_OPTIONS=( $( RmInArray "--relative" "${BACKUP_RSYNC_OPTIONS[@]}" ) )
    { local needle="$1"
      declare -a nArray  # we will build a new array
      while shift ; do
          if [[ "$needle" != "$1" ]] ; then
              nArray+=( "$1" )
          fi
      done
    } 2>>/dev/$DISPENSABLE_OUTPUT_DEV
    # we return the array as a string
    echo "${nArray[@]}"
}

