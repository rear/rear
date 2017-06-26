#
# In some cases SUSE has /media plus /media/cdrom and /media/floppy.
# On SLE11 the filesystem RPM contains them.
# On SLE12 they are dropped from the filesystem RPM because nowadays /run/media is used.
# There is the SUSE-internal issue https://bugzilla.suse.com/show_bug.cgi?id=890198
# and the "SUSE Linux Enterprise Server 12 Release Notes" mention it
# see https://www.suse.com/releasenotes/x86_64/SUSE-SLES/12/ that reads:
#   "/run/media/<user_name> is now used as top directory for removable
#    media mount points. It replaces /media , which is not longer available."
# Therefore for SLE12 "rear recover" must no longer create them.
# The following test for SLE12 products is intentionally sloppy
# because I <jsmeix@suse.de> have no better idea how to test for various
# possible SLE12-based products like "SUSE Linux Enterprise Server 12"
# "SUSE Linux Enterprise Desktop 12" "SUSE Linux Enterprise Server 12 SP1"
# "SUSE Linux Enterprise Desktop 12 SP1" "SUSE Linux Enterprise <whatever> <whichever>".
# Therefore it is triggered by the absence of /etc/os-release because
# I assume that the switch from /media to /run/media matches reasonably well
# with the switch from /etc/SuSE-release to /etc/os-release so that
# this test is also (hopefully) somewhat future-proof (e.g. for SLE13):
pushd $TARGET_FS_ROOT >/dev/null
test -f etc/os-release || mkdir -p media/cdrom media/floppy
popd >/dev/null

