[[ ! -d $VAR_DIR/sysreqs ]] && mkdir -m 755 $VAR_DIR/sysreqs

############################ M A I N ########################
{

echo
echo `hostname` - `date '+%F %R'`
echo


#
# OS information
#

echo "Operating system:"
if [[ -f /etc/SuSE-release ]]; then
    # lsb_release does not contain minor version (SP version) in SLE
    # get OS version from /etc/SuSE-release
    OSVER=`head -1 /etc/SuSE-release`
    # get OS patchlevel (SP) from /etc/SuSE-release
    OSLEVEL=`grep PATCHLEVEL /etc/SuSE-release  | cut -d= -f2`
    echo "${OSVER} SP${OSLEVEL}"
elif [[ -f /etc/redhat-release ]]; then
    cat /etc/redhat-release
elif [[ -f /etc/rear/os.conf ]]; then
    # The following 2 variables are listed as an example, and are already known by rear
    # OS_VENDOR=RedHatEnterpriseServer
    # OS_VERSION=6
    echo "${OS_VENDOR} ${OS_VERSION}"
else
    /usr/bin/lsb_release  --short --description
fi

echo
echo "Relax and recover version:"
/usr/sbin/rear -V
echo

#
# CPU & Memory information
#

# get number of processor cores
PROCS=`cat /proc/cpuinfo | grep "processor" | sort -u | wc -l`
# get processor speed (assumes all processors have same speed
SPEED=`cat /proc/cpuinfo | grep "cpu MHz" | sort -u | cut -d: -f2`
# determine the amount of memory the system had (this excludes kernel memory (how to determine this?)
TOTMEM=$((`grep MemTotal /proc/meminfo | cut -d: -f2| sed 's/kB//'` / 1024))

echo "There are ${PROCS} CPU core(s) at ${SPEED} MHz"
echo "${TOTMEM} MiB of physical memory"
echo

#
# VG information
#
echo "Volume Group info:"
vgs --units=g
echo
echo "Logical Volume Groups info:"
lvs --units=g
echo

#
# Disk information
#
# get swap space size
SWAP_KB=$( grep -v -e Filename -e /dev/dm- /proc/swaps | awk '{tot=tot+$3} END {print tot}' )
[[ -z "$SWAP_KB" ]] && SWAP_KB=0
# get vg00 size
VG00_GB=$( vgs --units=g | grep vg00 | awk '{print $6}' | sed 's/g//' )
# get /boot size
BOOT_KB=$(grep `df -P /boot | grep /boot | awk '{print $1}' | sed "s#/dev/##"` /proc/partitions | awk '{print $3}')
# calculate needed OS disk size (= vg00 size + swap size + /boot size)
TOTOS=$(echo "((($SWAP_KB+$BOOT_KB)/(1024*1024))+$VG00_GB)" | bc -l)
TOTOS=$(printf '%.2f' $TOTOS)

echo "Disk space requirements:"
echo "  OS (vg00 + swap + /boot)"
echo "    size: ${TOTOS} GiB"
echo "  Additional VGs"
size=0
for SIZE in $(vgs --units=g | grep -v -e vg00 -e VFree | awk '{print $6}' | sed 's/g//')
do
   size=$(echo "($size + $SIZE)" | bc -l)
done
echo "    size: "$size" GiB"
echo

#
# Network information
#

echo "Network Information:"
echo "  IP adresses:"
# all ip adresses with some extra info ( subnet + DNS name)
ip addr show | grep inet | grep -v 127.0.0. | sed -e "s/ brd.*//" -e "s/inet//" | while read ip; do
  echo "    ip ${ip%/*} subnet /${ip#*/} DNS name `dig +short -x ${ip%/*}`"
done
echo "  Default route:"
# default route
ip route show | grep default | cut -d' ' -f3 | sed -e "s/^/    /"
echo

#echo "Other System Requirements:"
#echo
} >$VAR_DIR/sysreqs/Minimal_System_Requirements.txt
