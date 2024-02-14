if [ "$OUTPUT" = "IPL" ]; then
    LogPrintError "Warning: OUTPUT=IPL is deprecated. Use OUTPUT=RAMDISK instead."
    OUTPUT=RAMDISK
fi

if [ "$OUTPUT" != "RAMDISK" ] ; then
   Error "Currently, only OUTPUT=RAMDISK is supported on s390/s390x"
fi
