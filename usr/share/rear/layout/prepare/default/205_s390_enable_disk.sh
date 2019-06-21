

#
# for s390 (zLinux) systems, the dasd device must be enabled 
# write in the layout the device to enable for recovery
#
enable_s390_disk() {

    dch=$(cat $LAYOUT_FILE | grep -v "^#" | grep "^dasd_channel" )

    echo "run chccwdev"
    while read line
    do
        device=$( echo $line | awk '{ print $4 }' ) 
        bus=$( echo $line | awk '{ print $2 }' ) 
        channel=$( echo $line | awk '{ print $5 }' ) 
        echo 'chccwdev:' $device ', bus:' $bus ', channel:' $channel
        chccwdev -e $bus 
    done < <( echo "$dch" )
}


if [[ "$ARCH" == "Linux-s390" && "$OS_VENDOR" != "SUSE_LINUX" ]]
then
    enable_s390_disk
fi
