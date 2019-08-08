# dasd disk device enable for s390 arch on rhel
# before we can compare or map the deviuces we must enable them
# note that this is a recovery operation

format_s390_disk() {

    dfmt=$(cat $LAYOUT_FILE | grep "^dasdfmt" )

    echo "run dasdfmt"
    while read line
    do
        echo 'dasdfmt:' "$line"
        # example format command: dasdfmt -b 4096 -d cdl -y /dev/dasda
        # where
        #  b is the block size
        #  d is the layout: 
        #   cdl - compatible disk layout (can be shared with zos and zvm apps)
        #   ldl - linux disk layout
        #  y - answer yes
        device=$( echo $line | awk '{ print $7 }' ) 
        blocksize=$( echo $line | awk '{ print $3 }' ) 
        layout=$( echo $line | awk '{ print $5 }' ) 
        echo 'dasdfmt:' $device ', blocksize:' $blocksize ', layout:' $layout
        # dasd format
        dasdfmt -b $blocksize -d $layout -y $device
    done < <( echo "$dfmt" )
}


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
            format_s390_disk
            enable_s390_disk
        ;;
        (Fedora)
            # handles RH
            format_s390_disk
            enable_s390_disk
        ;;
        (Debian)
            format_s390_disk
            enable_s390_disk
            # handles ubuntu also, may need to look at $OS_VENDOR also as dasd disk layout is distro specific
        ;;
        (Arch)
            # no cases for debian
        ;;
    esac
fi

