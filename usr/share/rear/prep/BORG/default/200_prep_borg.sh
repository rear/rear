# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 200_prep_borg.sh

# Check if BORGBACKUP_ARCHIVE_PREFIX is correctly set.
# Using '_' could result to some unpleasant side effects,
# as this character is used as delimiter in latter `for' loop ...
# Excluding other non alphanumeric characters is not really necessary,
# however it looks safer to me.
# We added - and : to the allowed list within the archive names.
if [[ $BORGBACKUP_ARCHIVE_PREFIX =~ [^a-zA-Z0-9\-:] ]] \
  || [[ -z $BORGBACKUP_ARCHIVE_PREFIX ]]; then
    Error "BORGBACKUP_ARCHIVE_PREFIX must be alphanumeric non-empty value only"
fi

# Create our own locales, used only for Borg restore.
mkdir -p "$ROOTFS_DIR/usr/lib/locale"
# localedef will fail when en_US is not available.
# Therefore, we should install the english language pack first to fix this.
locale -a | grep -q en_US || Error "Please install the English language pack first to have the en_US set"

localedef -f UTF-8 -i en_US "$ROOTFS_DIR/usr/lib/locale/en_US.UTF-8" || Error "Could not create locales ('en_US')"

# Activate $COPY_AS_IS_BORG from default.conf.
COPY_AS_IS+=( "${COPY_AS_IS_BORG[@]}" )

# Activate $PROGS_BORG from default.conf.
# Avoid user to accidentally override `borg' and `locale' and exclude them
# from Relax-and-Recover rescue/recovery system.
PROGS+=( "${PROGS_BORG[@]}" borg locale )
