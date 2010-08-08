# This script only contains the function "create_parted_script_for_recovery" needed by script
# /usr/share/rear/dr/Linux-ia64/30_mk_partitions_with_parted.sh
#
# GD - 20/May/2008 - added parted new/old layout intelligence

create_parted_script_for_recovery () {
# DESCRIPTION:this function allows to create a script which partitions the disk with parted
SCRIPT_FILE=$1  # the file in which the script will be saved ( ex : parted )
DEV=$2		# device, e.g. /dev/sda
DEVICE_PARTITION_FILE=$3         # the file containing the partition description of the device ( ex : partitions)


# check old/new version of parted
Log "parted version: `/sbin/parted -v`"
grep -q ^Number ${DEVICE_PARTITION_FILE} && Parted_layout=NEW || Parted_layout=OLD

echo "[ -f /tmp/parted.${2}.done ] && exit" > ${SCRIPT_FILE}
echo "parted -i ${DEV} mklabel gpt" >> ${SCRIPT_FILE}

NB_LINE=`cat ${DEVICE_PARTITION_FILE} | sed -e '/^$/d' | egrep -vi '^(Model|Disk|Minor|Partition|Sector|Number)' | wc -l`

 let a=1
while [ $a -le $NB_LINE ]
do

        #we read each first line of the device partition file
        exp=${a}p
        line=`cat  ${DEVICE_PARTITION_FILE} | sed -e '/^$/d' | egrep -vi '^(Model|Disk|Minor|Partition|Sector|Number)' | sed -n $exp`
	if [ "${Parted_layout}" = "OLD" ]; then
        MINOR=`printf "${line}" |awk 'BEGIN { FIELDWIDTHS = "6 11 11 12 22 15" } ;{ print $1 }'`
        START=`printf "${line}" |awk 'BEGIN { FIELDWIDTHS = "6 11 11 12 22 15" } ;{ print $2 }'`
        END=`printf "${line}" |awk 'BEGIN { FIELDWIDTHS = "6 11 11 12 22 15" } ;{ print $3 }'`
        FILESYSTEM=`printf "${line}" |awk 'BEGIN { FIELDWIDTHS = "6 11 11 12 22 15" } ;{ print $4 }'`
        NAME_=`printf  "${line}" |awk 'BEGIN { FIELDWIDTHS = "6 11 11 12 22 15" } ;{ print $5 }'`
	NAME=`echo ${NAME_} | sed -e 's/ //g'` # remove blanks
        FLAGS=`printf "${line}" |awk 'BEGIN { FIELDWIDTHS = "6 11 11 12 22 15" } ;{ print $6 }'`
	else # [ "${Parted_layout}" = "NEW" ]
	MINOR=`printf "${line}" |awk '{ print $1 }'`
	START=`printf "${line}" |awk '{ print $2 }'`
	END=`printf "${line}" |awk '{ print $3 }'`
	SIZE=`printf "${line}" |awk '{ print $4 }'`
	FILESYSTEM=`printf "${line}" |awk '{ print $5 }'`
	NAME_=`printf  "${line}" |awk 'BEGIN { FIELDWIDTHS = "8 8 8 8 10 7 10 20" } ;{ print $6 }'`
	NAME=`echo ${NAME_} | sed -e 's/ //g'` # remove blanks
	FLAGS=`printf "${line}" |awk 'BEGIN { FIELDWIDTHS = "8 8 8 8 10 7 10 20" } ;{ print $7 }'`
	fi # end of "${Parted_layout}"

        #and we create the partition

        echo "parted ${DEV} mkpart primary ${START} ${END}" >> ${SCRIPT_FILE}

        # then we set its name if there is one

        if [ ! -z "${NAME}" ]; then
                echo "parted ${DEV} name ${MINOR} ${NAME}" >> ${SCRIPT_FILE}
        fi

        # and finally we set all the flags of the partition:

        FLAGS_=`echo $FLAGS | tr ',' ' '`      #(ex: FLAGS_="lvm lba boot" )
        for CURRENT_FLAG in $FLAGS
        do
                echo "parted ${DEV} set ${MINOR} ${CURRENT_FLAG} on" >> ${SCRIPT_FILE}
        done
        let a=$[ $a + 1 ]
done

}
