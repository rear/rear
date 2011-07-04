#
# parse HP ACU CLI info and put it into $VAR_DIR/recovery/hpacucli
#
#

# do nothing unless we have hpacucli in our path
if ! has_binary hpacucli; then
    return
fi

# add hpacucli to rescue media
PROGS=( "${PROGS[@]}" hpacucli )
eval $(grep ON_DIR= $(get_path hpacucli))
COPY_AS_IS=( "${COPY_AS_IS[@]}" "$HPACUCLI_BIN_INSTALLATION_DIR" )

# step 1) find out slots
SLOTS=();
while read ; do
	# output is like
	#
	# Smart Array P400 in Slot 1    (sn: PAFGK0M9SWE047)
	#
	#

	# skip lines not containing "Slot" by checking wether REPLY remains unchanged when I replace Slot
	test "${REPLY//Slot/Schlomo}" = "$REPLY" && continue

	# report this controller
	Log "Detected $REPLY"

	# calculate Slot number
	SLOT="${REPLY##*Slot }"
	SLOT="${SLOT%% *}"
	SLOTS=( "${SLOTS[@]}" "$SLOT" )
done < <(hpacucli ctrl all show)

# do nothing if no supported controllers installed
if [ ${#SLOTS[@]} -eq 0 ] ; then
	Log "No compatible HP RAID controllers found or configured"
	return
fi


function write_build_array() {
	# this function takes the SLOT, PHYSICALDRIVES, RAIDLEVEL, LD_SectorsPerTrack,
	# LD_StripeSize, SPAREDIVES variables and writes out the appropriate hpacucli
	# commands to recreate the array

	# do nothing if we miss some information. This is normal because we are called also
	# at several places where there is no information (this makes the loop simpler to code).
	test "$SLOT" -a "$PHYSICALDRIVES" -a "$RAIDLEVEL" -a "$LD_SectorsPerTrack" -a "$LD_StripeSize" || return 0

	echo "hpacucli ctrl slot=$SLOT create type=ld drives=$PHYSICALDRIVES raid=${RAIDLEVEL} sectors=$LD_SectorsPerTrack stripesize=$LD_StripeSize"
	if test "$SPAREDRIVES" ; then
		# to add spare drives we first have to determine the array to which to add to.
		# we have to scan the current configuration and find the array that contains
		# the first physical drive from the freshly assembled logical drive.
		#
		# at the moment we just assume that the array naming order will be the same
		# AFTER we re-create the logical drives from scratch in the order that
		# they exist now. Please submit a bug if this does not work for you.
		#
		ARRAY="$(find_array_from_drive $SLOT ${PHYSICALDRIVES%%,*})"
		StopIfError "Could not determine array for newly created logical drive"

		test "$ARRAY"
		StopIfError "Could not determine array for newly created logical drive"

		echo "hpacucli ctrl slot=$SLOT array $ARRAY add spares=$SPAREDRIVES"
	fi


}

# go over slots and dump configuration
for SLOT in "${SLOTS[@]}" ; do
	# read logical drives and write out info about them

	LOGICALDRIVE=""
	RAIDLEVEL=""
	PHYSICALDRIVES=""
	SPAREDRIVES=""
	ARRAY=""

	mkdir -p $VAR_DIR/recovery/hpacucli/"Slot_$SLOT"
	StopIfError "Could not mkdir '$VAR_DIR/recovery/hpacucli/Slot_$SLOT'"

	# store complete config for each controller (=SLOT)
	hpacucli ctrl slot="$SLOT" show config >"$VAR_DIR/recovery/hpacucli/Slot_$SLOT/config.txt"
	StopIfError "Could not read read hpacucli configuration for slot $SLOT"

	while read ; do
		# output is like
		T=<<EOF
				Smart Array P400 in Slot 1    (sn: PAFGK0M9SWE047)

				   array A (SAS, Unused Space: 0 MB)

				      logicaldrive 1 (136.7 GB, RAID 1+0, OK)

				      physicaldrive 1I:1:7 (port 1I:box 1:bay 7, SAS, 146 GB, OK)
				      physicaldrive 1I:1:8 (port 1I:box 1:bay 8, SAS, 146 GB, OK)

				   array B (SAS, Unused Space: 0 MB)

				      logicaldrive 2 (410.1 GB, RAID 1+0, OK)

				      physicaldrive 1I:1:5 (port 1I:box 1:bay 5, SAS, 146 GB, OK)
				      physicaldrive 1I:1:6 (port 1I:box 1:bay 6, SAS, 146 GB, OK)
				      physicaldrive 2I:1:1 (port 2I:box 1:bay 1, SAS, 146 GB, OK)
				      physicaldrive 2I:1:2 (port 2I:box 1:bay 2, SAS, 146 GB, OK)
				      physicaldrive 2I:1:3 (port 2I:box 1:bay 3, SAS, 146 GB, OK)
				      physicaldrive 2I:1:4 (port 2I:box 1:bay 4, SAS, 146 GB, OK)

EOF
		# the information about the arrays seems to be irrelevant as
		# each array contains only one logical drive. Maybe different for
		# MSA1x00

		case "$REPLY" in
			# after unassigned we find all the drives that do not concern us
			*unassigned*)
				# dump previously collected info
				write_build_array >>"$VAR_DIR/recovery/hpacucli/Slot_$SLOT/hpacucli-commands.sh"
				LOGICALDRIVE=""
				PHYSICALDRIVES=""
				SPAREDRIVES=""
				RAIDLEVEL=""
				ARRAY=""
			;;
			*array*)
				ARRAY="${REPLY##*array }"
				ARRAY="${ARRAY%% *}"
			;;
			*logicaldrive*)
				# dump previously collected info
				write_build_array >>"$VAR_DIR/recovery/hpacucli/Slot_$SLOT/hpacucli-commands.sh"

				LOGICALDRIVE="${REPLY##*logicaldrive }"
				LOGICALDRIVE="${LOGICALDRIVE%% *}"

				RAIDLEVEL="${REPLY##*RAID }"
				RAIDLEVEL="${RAIDLEVEL%%,*}"

				# Dump logical drive configuration for information
				Log "Found Controller $SLOT Array $ARRAY Logical Drive $LOGICALDRIVE RAID $RAIDLEVEL"

				# retrieve detailed configuration for logical drive and store in LD_ variables
				hpacucli ctrl slot=$SLOT ld $LOGICALDRIVE show detail >"$VAR_DIR/recovery/hpacucli/Slot_$SLOT/ARRAY_$ARRAY-LOGICALDRIVE_$LOGICALDRIVE-detail.txt"
				StopIfError "Could not read logical drive details with hpacucli"

				# parse logical drive detail information into environment variables

				# the result of the following while IFS=: loop are environment variables like this:
				# (please note that LD_FaultTolerance is useless and $RAIDLEVEL should be used instead !)
				T=<<EOF
					LD_LogicalDrive=1
					LD_Size=136.7
					LD_FaultTolerance=RAID
					LD_Heads=255
					LD_SectorsPerTrack=32
					LD_Cylinders=35132
					LD_StripeSize=128
					LD_Status=OK
					LD_MultiDomainStatus=OK
					LD_ArrayAccelerator=Enabled
					LD_UniqueIdentifier=600508B100104E3953574E304F310004
					LD_DiskName=/dev/cciss/c0d1
					LD_MountPoints=None
					LD_LogicalDriveLabel=AA1C62C2PAFGK0N9SWN0O15584
EOF
				while IFS=: read key val ; do
					val="${val#* }"
					val="${val% *}"
					test "${key// /}" -a "$val" || continue # skip empty
					declare LD_${key// /}="$val"
				done <"$VAR_DIR/recovery/hpacucli/Slot_$SLOT/ARRAY_$ARRAY-LOGICALDRIVE_$LOGICALDRIVE-detail.txt"

				# reset physical drives lists
				PHYSICALDRIVES=""
				SPAREDRIVES=""
			;;
			*spare*)
				DRIVE="${REPLY##*physicaldrive }"
				DRIVE="${DRIVE%% *}"
				if test "$SPAREDRIVES" ; then
					SPAREDRIVES="$SPAREDRIVES,$DRIVE"
				else
					SPAREDRIVES="$DRIVE"
				fi
			;;
			*physicaldrive*)
				DRIVE="${REPLY##*physicaldrive }"
				DRIVE="${DRIVE%% *}"
				if test "$PHYSICALDRIVES" ; then
					PHYSICALDRIVES="$PHYSICALDRIVES,$DRIVE"
				else
					PHYSICALDRIVES="$DRIVE"
				fi
			;;
		esac
	done <"$VAR_DIR/recovery/hpacucli/Slot_$SLOT/config.txt"

	# dump collected information
	write_build_array >>"$VAR_DIR/recovery/hpacucli/Slot_$SLOT/hpacucli-commands.sh"

done # foreach
