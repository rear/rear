#
# layout/save/FDRUPSTREAM/Linux-s390/990_copy_disklayout_file.sh
#
# For s390 if ZVM naming is setup, then copy the disklayout.conf to the output location
# s390 optional naming override of dsklayout.conf to match the s390 filesystem naming conventions
# example:
# if the VM name / VM user id ('vmcp q userid') is HOSTA then conf is written as HOSTA.disklayout
# vars needed:
# ZVM_NAMING      - set in local.conf, if Y then enable naming override
# ARCH            - override only if ARCH is Linux-s390
#
# The copy of the disklayout.conf to the output location functionality
# is only done in case of BACKUP=FDRUPSTREAM which is intended because
# this functionality is not needed for the restore on s390 to work properly.
# It was only requested to make this file available for FDRUPSTREAM
# cf. https://github.com/rear/rear/pull/2142#discussion_r356696670

# Only for s390 when also ZVM naming is requested (cf. prep/GNU/Linux/400_guess_kernel.sh):
test "$ARCH" = "Linux-s390" || return 0
is_true "$ZVM_NAMING" || return 0

# Cf. https://manpages.debian.org/testing/s390-tools/vmcp.8.en.html
# An artificial bash array is used so that the first array element $VM_UID is the VM user id:
VM_UID=( $( vmcp q userid ) )
test $VM_UID || Error "Could not set VM_UID ('vmcp q userid' did not return the VM user id)"

scheme="$( url_scheme "$OUTPUT_URL" )"
path="$( url_path "$OUTPUT_URL" )"
opath="$( output_path "$scheme" "$path" )"
test $opath || Error "Could not determine output path from OUTPUT_URL='$OUTPUT_URL'"

LogPrint "s390 disklayout.conf will be saved as $opath/$VM_UID.disklayout.conf"
mkdir $v -p "$opath"
cp $v $DISKLAYOUT_FILE $opath/$VM_UID.disklayout.conf || Error "Failed to copy '$DISKLAYOUT_FILE' to $opath/$VM_UID.disklayout.conf"
