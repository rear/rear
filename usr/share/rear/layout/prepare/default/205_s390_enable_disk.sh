# DASD disk device enablement for IBM Z (s390)
# Before we can compare or map DASD devices we must enable them.
# This operation is only needed during "rear recover".

# Only needed on IBM Z (s390):
test "$ARCH" = "Linux-s390" || return 0
# TODO: have it as an architecture specific script
# usr/share/rear/layout/prepare/Linux-s390/205_s390_enable_disk.sh

format_s390_disk() {

    dfmt=$( cat $LAYOUT_FILE | grep "^dasdfmt" )

    # FIXME: Plain 'echo' goes to stdout that goes into the log
    # so I <jsmeix@suse.de> wonder if that is the intended behaviour
    # or if actually the user should be informed e.g. via LogPrint?
    echo "run dasdfmt"
    while read line ; do
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
        layout=$( echo $line | awk '{ print tolower($5) }' )
        if [[ "$layout" == "ldl" ]] ; then
            # listDasdLdl contains devices such as /dev/dasdb that are formatted as LDL
            # LDL formatted disks are already partitioned and should not be partitioned with parted or fdasd , it will fail
            # this var, listDasdLdl, is used by 100_include_partition_code.sh to exclude writing partition code to diskrestore.sh for LDL disks
            listDasdLdl+=( $device )
            # FIXME: See above, perhaps the user should be informed e.g. via LogPrint?
            echo "LDL disk added to listDasdLdl:" ${listDasdLdl[@]}
        fi
        # FIXME: See above, perhaps the user should be informed e.g. via LogPrint?
        echo 'dasdfmt:' $device ', blocksize:' $blocksize ', layout:' $layout
        # dasd format
        dasdfmt -b $blocksize -d $layout -y $device
        # FIXME: Why first   dfmt=$( cat $LAYOUT_FILE | grep "^dasdfmt" )
        # plus then here     < <( echo "$dfmt" )
        # and not just only  < <( grep "^dasdfmt " "$LAYOUT_FILE" )
        # as we usually do it in other scripts to read certain lines in disklayout.conf?
    done < <( echo "$dfmt" )
}


enable_s390_disk() {

    # FIXME: It seems to be not needed to explicitly exclude comments
    # because grep "^dasd_channel" won't match comment lines:
    dch=$( cat $LAYOUT_FILE | grep -v "^#" | grep "^dasd_channel" )

    # FIXME: See above, perhaps the user should be informed e.g. via LogPrint?
    echo "run chccwdev"
    while read line ; do
        # FIXME: See above, perhaps the user should be informed e.g. via LogPrint?
        echo 'dasd channel:' "$line"
        device=$( echo $line | awk '{ print $4 }' )
        bus=$( echo $line | awk '{ print $2 }' )
        channel=$( echo $line | awk '{ print $5 }' )
        # FIXME: See above, perhaps the user should be informed e.g. via LogPrint?
        echo 'chccwdev:' $device ', bus:' $bus ', channel:' $channel
        # dasd channel enable
        chccwdev -e $bus
        # FIXME: Why first   dch=$( cat $LAYOUT_FILE | grep -v "^#" | grep "^dasd_channel" )
        # plus then here     < <( echo "$dch" )
        # and not just only  < <( grep "^dasd_channel " "$LAYOUT_FILE" )
        # as we usually do it in other scripts to read certain lines in disklayout.conf?     
    done < <( echo "$dch" )
}

# May need to look at $OS_VENDOR also as DASD disk layout is distro specific:
case $OS_MASTER_VENDOR in
    (SUSE|Fedora|Debian)
        # "Fedora" also handles Red Hat
        # "Debian" also handles Ubuntu
        enable_s390_disk
        format_s390_disk
        ;;
    (*)
        LogPrintError "No code for DASD disk device enablement on $OS_MASTER_VENDOR"
        ;;
esac
