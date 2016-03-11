
# FIXME: Provide a leading comment what this script is about.

test -d $VAR_DIR/sysreqs || mkdir -m 755 $VAR_DIR/sysreqs

############################ M A I N ########################
{

echo
echo $( hostname ) - $( date '+%F %R' )
echo

#
# OS information
#
echo "Operating system:"
if test -f /etc/SuSE-release ; then
    # lsb_release does not contain minor version (SP version) in SLE
    # get OS version from /etc/SuSE-release
    OSVER=$( head -1 /etc/SuSE-release )
    # get OS patchlevel (SP) from /etc/SuSE-release
    OSLEVEL=$( grep PATCHLEVEL /etc/SuSE-release  | cut -d= -f2 )
    echo "${OSVER} SP${OSLEVEL}"
elif test -f /etc/redhat-release ; then
    cat /etc/redhat-release
elif test -f /etc/rear/os.conf ; then
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
PROCS=$( cat /proc/cpuinfo | grep "processor" | sort -u | wc -l )
# get processor speed (assumes all processors have same speed
SPEED=$( cat /proc/cpuinfo | grep "cpu MHz" | sort -u | cut -d: -f2 )
# determine the amount of memory in MiB the system had
# (this excludes kernel memory (how to determine this?))
memory_in_kB=$( grep MemTotal /proc/meminfo | cut -d: -f2 | sed 's/kB//' )
TOTMEM=$(( memory_in_kB / 1024 ))

echo "There are $PROCS CPU core(s) at $SPEED MHz"
echo "$TOTMEM MiB of physical memory"
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
test "$SWAP_KB" || SWAP_KB=0
# get vg00 size
VG00_GB=$( vgs --units=g | grep vg00 | awk '{print $6}' | sed 's/g//' )
test "$VG00_GB" || VG00_GB=0
# get size of a separated /boot partition
boot_partition_device_base_name=$( df -P /boot | grep /boot | awk '{print $1}' | sed "s#/dev/##" )
# if there is a separated /boot partition its boot_partition_device_base_name is something like 'sda2'
if test "$boot_partition_device_base_name" ; then
  BOOT_KB=$( grep $boot_partition_device_base_name /proc/partitions | awk '{print $3}' )
else
  BOOT_KB=0
fi
# calculate needed OS disk size in GiB ( = vg00 size + swap size + /boot size )
TOTOS=$( echo "( ( $SWAP_KB + $BOOT_KB ) / ( 1024 * 1024 ) ) + $VG00_GB" | bc -l )
TOTOS=$( printf '%.2f' $TOTOS )
test "$TOTOS" || TOTOS=0
# FIXME: it seems the root partition size is mising because
# the root partition is at least not always included in vg00 size.
echo "Disk space requirements:"
echo "  OS (vg00 + swap + /boot)"
echo "    size: $TOTOS GiB"
echo "  Additional VGs"
size=0
for SIZE in $( vgs --units=g | grep -v -e vg00 -e VFree | awk '{print $6}' | sed 's/g//' ) ; do
    test "$SIZE" && size=$( echo "$size + $SIZE" | bc -l )
done
echo "    size: $size GiB"
echo

#
# Network information
#
echo "Network Information:"
echo "  IP adresses:"
# all ip adresses with some extra info ( subnet + DNS name)
# FIXME: it seems that can go wrong for IPv6 addresses
# perhaps <<ip -4 addr show>> is meant or <<grep 'inet'>> to exclude inet6
# or when IPv6 should be included it should be <<sed ... -e "s/inet6//" -e "s/inet//" >>
# or whatever?
# I <jsmeix@suse.de> gues that IPv6 should be included (i.e. I added -e "s/inet6//").
# Furthermore I do not know if additional stuff like "scope global temporary dynamic"
# is intended in the output, if not it should be <<while read ip junk ; do>>
# to get rid of such additional stuff (for now I keep that additional stuff).
# Finally I do not know if "... DNS name" should be output when there is no DNS name.
# If "... DNS name" should not be output when there is no DNS name
# a test whether or not <<$( dig +short -x ${ip%/*} )>> is empty would help.
ip addr show | grep inet | grep -v 127.0.0. | sed -e "s/ brd.*//" -e "s/inet6//" -e "s/inet//" | while read ip ; do
  echo "    ip ${ip%/*} subnet /${ip#*/} DNS name $( dig +short -x ${ip%/*} )"
done
echo "  Default route:"
# default route
ip route show | grep default | cut -d' ' -f3 | sed -e "s/^/    /"
echo

#echo "Other System Requirements:"
#echo
} >$VAR_DIR/sysreqs/Minimal_System_Requirements.txt

