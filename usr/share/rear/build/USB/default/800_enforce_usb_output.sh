# Verify there is the correct OUTPUT=USB in $ROOTFS_DIR/etc/rear/local.conf

# The reason for this verification is unknown,
# see https://github.com/rear/rear/pull/3103
# and https://github.com/rear/rear/issues/1571#issuecomment-343461088
# and https://github.com/rear/rear/issues/1571#issuecomment-343516020

real_output=$( source $ROOTFS_DIR/etc/rear/local.conf; echo $OUTPUT )
test "USB" = "$real_output" && return

# At this point we run this script build/USB/default/800_enforce_usb_output.sh
# which means there is OUTPUT=USB in etc/rear/local.conf
# (ortherwise this script would not have been picked up by the SourceStage function)
# cf. https://github.com/rear/rear/pull/3103#issuecomment-1860001618
# and https://github.com/rear/rear/pull/3103#issuecomment-1860169199
# but in $ROOTFS_DIR/etc/rear/local.conf there is not OUTPUT=USB
# so OUTPUT got somehow modified in $ROOTFS_DIR/etc/rear/local.conf 
# after etc/rear/local.conf got copied via build/GNU/Linux/100_copy_as_is.sh
# which is a bug in ReaR:
BugError "OUTPUT=USB is used but that is missing in $ROOTFS_DIR/etc/rear/local.conf"
