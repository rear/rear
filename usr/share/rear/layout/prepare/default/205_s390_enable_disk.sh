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
        chccwdev -e $bus 
    done < <( echo "$dch" )
}



if [[ "$ARCH" == "Linux-s390"  ]]
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

cat >>$LAYOUT_CODE << 'EOF'

#
# for s390 (zLinux) systems, the dasd device must be enabled 
# write in the layout the device to enable for recovery
#
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
        chccwdev -e $bus 
    done < <( echo "$dch" )
}



if [[ "$ARCH" == "Linux-s390"  ]]
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
EOF
