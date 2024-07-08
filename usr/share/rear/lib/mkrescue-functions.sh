CategoriseDev () {
##################
# Purpose is to find out to which device category a device belongs to
# input: /dev/hda1, /dev/md0, /dev/vg00/lvol01
# output: MD | LVM | NORMAL
Log "CategoriseDevice called with '$@'"
local dev=${1}
if [ -f ${dev}  ]; then
                DevMajorNr="-1"         # a normal file
        else
                # see linux/Documentation/devices.txt
                DevMajorNr=`ls -Ll ${1} | awk '{print $5}' | cut -d"," -f 1`
        fi
        case ${DevMajorNr} in
        9)              # Software RAID md device
                        echo 'MD' ;;
        58|253|254)     # LVM
                        echo 'LVM' ;;
        *)              # default
                        echo 'NORMAL' ;;
        esac
}

FindPhysicalDevice () {
Log "FindPhysicalDevice called with '$@'"
##################
# Purpose is to find physical device underneath a meta device or lvm
# input: /dev/hda1, /dev/vg00/lvol1, /dev/md0 (arg1), MD, LVM, NORMAL (arg2)
# output: /dev/hda, /dev/sdb, /dev/cciss/c0d1
local mdline
local VG
case "${2}" in
	"NORMAL")	# IDE, SCSI, RAID disk
		# input=$1, output=$Dev (hda1)
		ParseDevice ${1}
		StopIfError "Parsing device failed: $1"
		# input=$Dev, output=$dsk
		ParseDisk $Dev
		StopIfError "Parsing disk failed: $Dev"
		echo "/dev/$dsk"
		;;
	"MD")		# software Raid - find disks under /dev/md?
		ParseDevice ${1}
		StopIfError "Parsing device failed: $1"
		cat /proc/mdstat | grep "${Dev}" | cut -d" "  -f 5- | tr " "  "\n" | \
		while read mdline
		do
			local Dev=`echo "${mdline}" | sed -e 's;\[.*;;'`
			ParseDisk ${Dev}
			StopIfError "Parsing disk failed: $Dev"
			echo "/dev/${dsk}"
		done
		;;
	"LVM")		# LVM - find disks under /dev/vg??/lvol??
		[ -c /dev/mapper/control ]
		StopIfError "LVM version 1 not supported"
		for disk in $(lvm vgdisplay -v 2>/dev/null | awk -F\ + '/PV Name/ {print $4}');
		do
			local devcat=$(CategoriseDev ${disk})
			if [ ${devcat} = 'NORMAL' ]; then
				ParseDisk ${disk}
				StopIfError "Parsing disk ${disk} failed"
			else
				FindPhysicalDevice ${disk} ${devcat}
			fi
			echo "${dsk}"
		done
		;;
esac
}

ParseDevice () {
###########
# input $1 is a line containing as 1st argument a file system device, eg.
# /dev/hda1, /dev/sdb1, /dev/md0, /dev/disk/c1t0d0, or even devfs alike
# /dev/ide/host0/bus0/target0/lun0/part2
# Output: Dev: hda1, sdb1, md0, md/0, disk/c1t0d0, vg_sd/lvol1
#        _Dev: hda1, sdb1, md0, md_0, disk_c1t0d0, vg%137sd_lvol1
#Dev=`echo ${1} | awk '{print $1}' | cut -d"/" -f 3-`
#_Dev=`echo ${Dev} | sed -e 's/_/%137/' | tr "/" "_"`
	Dev=${1#*/dev/}
	Dev=${Dev// /}
	_Dev=${Dev//_/%137}
	_Dev=${_Dev//\//_}
}

ParseDisk () {
Log "ParseDisk called with '$@'"
#########
# input is $1 (most likely $Dev as arg.; e.g. sda1, disk/c1t0d0)
# output is dsk (e.g. sda, disk/c1t0) and _dsk (e.g. sda, disk_c1t0)

# is it one of those with "p" at the end?
# this will match: Mylex (rd/c?d?p?), Compaq IDA (ida/c?d?p?),
# Compaq Smart (cciss/c?d?p?), AMI Hyperdisk (amiraid/ar?p?),
# IDE Raid (e.g. Promise Fastrak) (ataraid/d?p?), EMD (emd/?p?) and
# Carmel 8-port SATA (carmel/?p?)
local DEVwP
local disc
#DEVwP=`expr "${1}" : "\(\(cciss\|rd\|ida\)/c[0-9]\+d[0-9]\+p[0-9]\+\|amiraid/ar[0-9]\+p[0-9]\+\|ataraid/d[0-9]\+p[0-9]\+\|\(emd\|carmel\)/[0-9]\+p[0-9]\+\)"`

case "$1" in
	*rd[/!]c[0-9]d[0-9]p*|*cciss[/!]c[0-9]d[0-9]p*|*ida[/!]c[0-9]d[0-9]p*|*amiraid[/!]ar[0-9]p*|*emd[/!][0-9]p*|*ataraid[/!]d[0-9]p*|*carmel[/!][0-9]p*)
	DEVwP=1
	Log "ParseDisk recognized DEVwP for $1"
	;;
	*)
	DEVwP=
	;;
esac


if [ -c /dev/.devfsd ]; then
   # e.g. disc=ide/host0/bus0/target0/lun0/disc
   disc=`echo ${1} | cut -d"p" -f 1`disc
   if [ -b /dev/${disc} ]; then # I'm paranoid I know
     # to please sfdisk we have to backtrace the old style name (sda)
     dsk=`ls -l /dev | grep ${disc} | awk '{print $9}'`
   else
     # maybe devfs was configured in old style only?
     if [ -z $DEVwP ]; then
       dsk=`echo ${1} | sed -e 's/[0-9]//g'`      # sda
     else
       dsk=`echo ${1} | sed -e 's/p[0-9]\+$//g'`  # cXdX
     fi
   fi
else
   if [ -z $DEVwP ]; then
     dsk=`echo ${1} | sed -e 's/[0-9]//g'`      # sda
   else
     dsk=`echo ${1} | sed -e 's/p[0-9]\+$//g'`  # cXdX
   fi
fi
_dsk=`echo ${dsk} | tr "/" "_"`
}

#-----<--------->-------

Find_Root_Partition() {
echo $1 | cut -d"p" -f2- | sed -e 's/[a-zA-Z\/]//g'
}
#-----<--------->-------

Divide () {
#########
num1=$1
num2=$2

# divide with floating numbering
bc -l <<EOF
${num1}/${num2}
EOF
}
#-----<--------->-------

Multiply () {
###########
num1=$1
num2=$2

bc -l <<EOF
${num1}*${num2}
EOF
}
#-----<--------->-------

FixSfdiskPartitionFile () {
#^^^^^^^^^^^^^^^^^^^^^^
# Sometimes we have a warning message in the partitions.$_dsk file which
# makes sfdisk fail at restore time (we will remove those lines)
# parameter: $1 is the sfdisk output file to fix

grep -Evi '(^warning|^dos)'  "$1" > "${TMP_DIR}/partitions.tmp"

# If LANG is not set to C (it should be) and sfdisk is producing locale specific comments
# for example in French something like "N<degree sign (U+00B0)> table de partition de "
# where <degree sign (U+00B0)> means one unicode character (in UTF-8 two bytes 0xC2 0xB0)
# then we should replace the "N" with hash(#) sign.
sed -e 's/^N/#/' <"${TMP_DIR}/partitions.tmp" >"$1"
rm -f $v "${TMP_DIR}/partitions.tmp" >&2
}

#-----<--------->-------
CheckForSwapLabel () {
###################
# Swap devices may have LABELs too - need to trace label if set
# Input: /dev/swap-dev
# Output: SWAPLABEL="" for no label, or "-L LABEL-swap" if label found
SWAPLABEL=""
# LABEL=SWAP-dev  swap  swap  defaults 0  0
while read LABEL junk
do
	LABEL="${LABEL/*=/}"
	if dd if=$1 bs=1024 count=10 2>/dev/null | strings | grep -q "${LABEL}" ; then
		SWAPLABEL="-L ${LABEL}"
		Log "Found swap label $LABEL on $1"
	fi
done < <(grep "LABEL=" /etc/fstab | grep swap)
}

