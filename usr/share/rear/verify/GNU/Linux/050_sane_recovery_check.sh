# 050_sane_recovery_check
#
# recover workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# make sure that we are on a recovery system
[ -s /etc/scripts/system-setup ]
StopIfError "This it not a $PRODUCT rescue system."
#
