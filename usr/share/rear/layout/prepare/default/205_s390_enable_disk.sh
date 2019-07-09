# dasd disk device enable for s390 arch on rhel
# before we can compare or map the deviuces we must enable them
# note that this is a recovery operation

enable_s390_disk() {

    dch=$(cat $LAYOUT_FILE | grep -v "^#" | grep "^dasd_channel" )

    echo "run chccwdev"
    while read line
    do
        echo 'dasd channel:' "$line"
        device=$( echo $line | awk '{ print $4 }' ) 
        bus=$( echo $line | awk '{ print $2 }' ) 
        channel=$( echo $line | awk '{ print $5 }' ) 
        echo 'chccwdev:' $device ', bus:' $bus ', channel:' $channel
        # dasd channel enable
        chccwdev -e $bus 
    done < <( echo "$dch" )
}

if [ "$ARCH" == "Linux-s390" ]
then
    case $OS_MASTER_VENDOR in
        (SUSE)
            # no cases for suse
        ;;
        (Fedora)
            # handles RH
            enable_s390_disk
        ;;
        (Debian)
            # no cases for debian
            # handles ubuntu also, may need to look at $OS_VENDOR also as dasd disk layout is distro specific
        ;;
        (Arch)
            # no cases for debian
        ;;
    esac
fi

