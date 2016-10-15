# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 10_prep_borg.sh

# Create our own locales, used only for Borg restore
mkdir -p $ROOTFS_DIR/usr/lib/locale
localedef -f UTF-8 -i en_US $ROOTFS_DIR/usr/lib/locale/rear.UTF-8
StopIfError "Could not create locales"

# Activate $COPY_AS_IS_BORG from default.conf
COPY_AS_IS=( "${COPY_AS_IS[@]}" "${COPY_AS_IS_BORG[@]}" )

# Activate $PROGS_BORG from default.conf
# Avoid user to accidentelly override `borg' and `locale' and exclude them
# from Relax-and-Recover rescue/recovery system
PROGS=( "${PROGS[@]}" "${PROGS_BORG[@]}" borg locale )
