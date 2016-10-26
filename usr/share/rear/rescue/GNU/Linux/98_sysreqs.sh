# Purpose of this script is to create a file which contains
# the minimal system requirements we need to recreate this
# system in a remote DRP site
# Output file: /var/lib/rear/sysreqs/Minimal_System_Requirements.txt
# This is just for your information and the output is nowhere else
# used by rear whatsoever.

test -d $VAR_DIR/sysreqs || mkdir -m 755 $VAR_DIR/sysreqs

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
echo "Relax-and-Recover version:"
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

echo "There are $PROCS CPU core(s) at $SPEED MHz"
echo "$(( memory_in_kB / 1024 )) MiB of physical memory"
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
echo "Disk space requirements:"
while read junk dev size label
do
   echo "Device $dev has a size of $((size/1024/1024/1024)) Gib (label $label)"
done < <(grep "^disk" $LAYOUT_FILE)
echo

#
# Network information
#
echo "Network Information:"
echo "  IP adresses:"
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
  DNSname="$( dig +short -x ${ip%/*} )"
  if test -z "$DNSname" ; then
      echo "    ip ${ip%/*} subnet /${ip#*/}"
  else
      echo "    ip ${ip%/*} subnet /${ip#*/} DNS name $( dig +short -x ${ip%/*} )"
  fi
done

echo "  Default route:"
# default route
ip route show | grep default | cut -d' ' -f3 | sed -e "s/^/    /"
echo

} >$VAR_DIR/sysreqs/Minimal_System_Requirements.txt

