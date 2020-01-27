#
# layout/save/FDRUPSTREAM/Linux-s390/990_copy_disklayout_file.sh
#
# For s390 if ZVM naming is setup, then copy the disklayout.conf to the output location
# s390 optional naming override of dsklayout.conf to match the s390 filesytem naming conventions
# example:
# if the vm name (cp q userid) is HOSTA then conf is written as HOSTA.disklayout
# vars needed:
# ZVM_NAMING      - set in local.conf, if Y then enable naming override
# ARCH            - override only if ARCH is Linux-s390
#
# The copy of the disklayout.conf to the output location functionality
# is only done in case of BACKUP=FDRUPSTREAM which is intended because
# this functionality is not needed for the restore on s390 to work properly.
# It was only requested to make this file available for FDRUPSTREAM
# cf. https://github.com/rear/rear/pull/2142#discussion_r356696670

scheme=$( url_scheme $OUTPUT_URL )
host=$( url_host $OUTPUT_URL )
path=$( url_path $OUTPUT_URL )
opath=$( output_path $scheme $path )


if [[ "$ZVM_NAMING" == "Y" && "$ARCH" == "Linux-s390" ]] ; then 
      VM_UID=$(vmcp q userid |awk '{ print $1 }')
	
      if [[ -z $VM_UID ]] ; then
            Error "VM UID is not set, VM UID is set from call to vmcp.  Please make sure vmcp is available and 'vmcp q userid' returns the vm login id"
      fi
      if [[ -z $opath ]] ; then
            Error "Output path is not set, please check OUTPUT_URL in local.conf."
      fi

      LogPrint "s390 disklayout.conf will be saved as $opath/$VM_UID.disklayout.conf"
      mkdir -pv $opath
      cp $v $DISKLAYOUT_FILE $opath/$VM_UID.disklayout.conf || Error "Failed to copy disklayout.conf ($DISKLAYOUT_FILE) to opath/$VM_UID.disklayout.conf"
fi

