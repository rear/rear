#!/bin/bash
#
#  This is a sample /etc/dhcpcd.sh script.
#  /etc/dhcpcd.sh script is executed by dhcpcd daemon
#  any time it configures or shuts down interface.
#  The following parameters are passed to dhcpcd.exe script:
#  $1 = HostInfoFilePath, e.g  "/var/lib/dhcpcd/dhcpcd-eth0.info"
#  $2 = "up" if interface has been configured with the same
#       IP address as before reboot;
#  $2 = "down" if interface has been shut down;
#  $2 = "new" if interface has been configured with new IP address;
#
#  Sanity checks

if [ $# -lt 2 ]; then
  logger -s -p local0.err -t dhcpcd.sh "wrong usage"
  exit 1
fi

hostinfo="$1"
state="$2"

# Sourcing HostInfo file for configuration parameters
[ -e "${hostinfo}" ] && source "${hostinfo}"

case "${state}" in
    up)
    logger -s -p local0.info -t dhcpcd.sh \
    "interface ${INTERFACE} has been configured with old IP=${IPADDR}"
    # Put your code here for when the interface has been brought up with an
    # old IP address here
    ;;

    new)
    logger -s -p local0.info -t dhcpcd.sh \
    "interface ${INTERFACE} has been configured with new IP=${IPADDR}"
    # Put your code here for when the interface has been brought up with a
    # new IP address
    ;;

    down) logger -s -p local0.info -t dhcpcd.sh \
    "interface ${INTERFACE} has been brought down"
    # Put your code here for the when the interface has been shut down
    ;;
esac
exit 0

