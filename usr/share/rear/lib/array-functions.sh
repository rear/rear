# some array functions

# return wether $1 equals one of the remaining arguments
function IsInArray() {
	search="$1"
	shift
	while test $# -gt 0 ; do
		test "$search" = "$1" && return 0
		shift
	done
	return 1
}

