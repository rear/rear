# DASD disk device enablement for IBM Z (s390)
# Before we can compare or map DASD devices we must enable them.
# This operation is only needed during "rear recover".

format_s390_disk() {
    LogPrint "run dasdfmt"
    while read line ; do
        LogPrint 'dasdfmt:' "$line"
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
            LogPrint "LDL disk '$device' will not be partitioned (LDL disks are already partitioned)"
        fi
        LogPrint 'dasdfmt:' $device ', blocksize:' $blocksize ', layout:' $layout
        # dasd format
        dasdfmt -b $blocksize -d $layout -y $device
    done < <( grep "^dasdfmt " "$LAYOUT_FILE" )
}


enable_s390_disk() {
    LogPrint "run chccwdev"
    while read line ; do
        LogPrint 'dasd channel:' "$line"
        device=$( echo $line | awk '{ print $4 }' )
        bus=$( echo $line | awk '{ print $2 }' )
        channel=$( echo $line | awk '{ print $5 }' )
        LogPrint 'chccwdev:' $device ', bus:' $bus ', channel:' $channel
        # dasd channel enable
        chccwdev -e $bus
    done < <( grep "^dasd_channel " "$LAYOUT_FILE" )
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
