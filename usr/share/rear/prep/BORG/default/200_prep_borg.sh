# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 200_prep_borg.sh

# Check if BORGBACKUP_ARCHIVE_PREFIX is correctly set.
# Using '_' could result to some unpleasant side effects,
# as this character is used as delimiter in latter `for' loop ...
# Excluding other non alphanumeric characters is not really necessary,
# however it looks safer to me.
# I'm sure archive handling can be done better, but no time for it now ...
if [[ $BORGBACKUP_ARCHIVE_PREFIX =~ [^a-zA-Z0-9] ]] \
|| [[ -z $BORGBACKUP_ARCHIVE_PREFIX ]]; then
    Error "BORGBACKUP_ARCHIVE_PREFIX must be alphanumeric non-empty value only"
fi

# Create our own locales, used only for Borg restore.
mkdir -p $ROOTFS_DIR/usr/lib/locale
localedef -f UTF-8 -i en_US $ROOTFS_DIR/usr/lib/locale/rear.UTF-8
StopIfError "Could not create locales"

# Activate $COPY_AS_IS_BORG from default.conf.
COPY_AS_IS+=( "${COPY_AS_IS_BORG[@]}" )

# Activate $PROGS_BORG from default.conf.
# Avoid user to accidentally override `borg' and `locale' and exclude them
# from Relax-and-Recover rescue/recovery system.
PROGS+=( "${PROGS_BORG[@]}" borg locale )
