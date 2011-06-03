# some array functions

# return wether $1 equals one of the remaining arguments
function IsInArray() {
	local needle="$1"
	while shift; do
		[[ "$needle" == "$1" ]] && return 0
	done
	return 1
}
