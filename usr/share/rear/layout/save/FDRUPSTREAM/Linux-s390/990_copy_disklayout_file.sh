#
# For s390 if ZVM naming is setup, then copy the disklayout.conf to the output location
# s390 optional naming override of dsklayout.conf to match the s390 filesytem naming conventions
# example:
# if the vm name (cp q userid) is HOSTA then conf is written as HOSTA.disklayout
# vars needed:
# ZVM_NAMING      - set in local.conf, if Y then enable naming override
# ARCH            - override only if ARCH is Linux-s390
# 

scheme=$( url_scheme $OUTPUT_URL )
host=$( url_host $OUTPUT_URL )
path=$( url_path $OUTPUT_URL )
opath=$( output_path $scheme $path )


if [[ "$ZVM_NAMING" == "Y" && "$ARCH" == "Linux-s390" ]] ; then 
      VM_UID=$(vmcp q userid |awk '{ print $1 }')
      LogPrint "s390 dislayout.conf will be saved as $(opath)/$VM_UID.disklayout.conf"
      cp $v $DISKLAYOUT_FILE ${opath}/"$VM_UID".disklayout.conf || Error "Failed to copy disklayout.conf ($DISKLAYOUT_FILE) to ${opath}/"$VM_UID".disklayout.conf"
fi

