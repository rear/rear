
#
# functions to use with HP Hardware RAID (Smart Array and compatible)
#
#

function find_array_from_drive() {
	# call hpacucli for the slot $1 and find the array that contains the drive $2

	while read ; do
		case $REPLY in
			*array*)
				ARRAY="${REPLY##*array }"
				ARRAY="${ARRAY%% *}"
			;;
			*drive*$2*)
				echo $ARRAY
				return 0
			;;
		esac
	done < <(hpacucli ctrl slot=$1 show config)
	return 1 # here we come only if we did not find the drive
}


