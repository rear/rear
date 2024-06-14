# Verify there is the correct OUTPUT=USB in $ROOTFS_DIR/etc/rear/local.conf

# This script was added in 2011 as build/USB/default/80_enforce_usb_output.sh via
# https://github.com/rear/rear/commit/4ec9ed4aa58787f42ad2946d68358d1de3417a60
# with only this git commit comment
# "Make sure OUTPUT=USB is enforced in udev workflow during recover"
# but the reason for this verification script is unknown,
# see the description below and
# see https://github.com/rear/rear/pull/3110
# and https://github.com/rear/rear/pull/3110#issuecomment-1862366094
# and https://github.com/rear/rear/pull/3103
# and https://github.com/rear/rear/issues/1571#issuecomment-343461088
# and https://github.com/rear/rear/issues/1571#issuecomment-343516020

local_conf_output=$( source $ROOTFS_DIR/etc/rear/local.conf ; echo $OUTPUT )
test "USB" = "$local_conf_output" && return

# At this point we run this script build/USB/default/800_enforce_usb_output.sh
# which means there is OUTPUT=USB in etc/rear/local.conf
# (ortherwise this script is not picked up by the SourceStage function)
# cf. https://github.com/rear/rear/pull/3103#issuecomment-1860001618
# and https://github.com/rear/rear/pull/3103#issuecomment-1860169199
# but in $ROOTFS_DIR/etc/rear/local.conf there is not OUTPUT=USB
# so somehow OUTPUT got modified in $ROOTFS_DIR/etc/rear/local.conf 
# after etc/rear/local.conf was copied via build/GNU/Linux/100_copy_as_is.sh
# i.e. between build/GNU/Linux/100_copy_as_is.sh and build/USB/default/800_enforce_usb_output.sh
# but as of this writing (19. Dec. 2023) nothing could be found in those build stage scripts
# which modifies $ROOTFS_DIR/etc/rear/local.conf (at least nothing obvious was found)
# cf. https://github.com/rear/rear/pull/3110#issuecomment-1862366094
# nevertheless it would be a bug in ReaR if OUTPUT got modified in $ROOTFS_DIR/etc/rear/local.conf
LogPrintError "OUTPUT=USB is used but that is missing in $ROOTFS_DIR/etc/rear/local.conf"
LogPrintError "See https://github.com/rear/rear/pull/3110 and follow the links therein"
BugError "'rear $WORKFLOW' uses OUTPUT=USB which will not be used for 'rear recover'"
