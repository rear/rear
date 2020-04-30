# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.
#
# 100_get_suffix.sh

# Do we have Borg binary?
has_binary borg
StopIfError "Could not find Borg binary"

# Let's find largest suffix in use, and increment it by 1.
BORGBACKUP_SUFFIX=0

for i in \
$( cat "$BORGBACKUP_ARCHIVE_CACHE" | grep "^${BORGBACKUP_ARCHIVE_PREFIX}_" \
| awk '{print $1}' )
do
    suffix_tmp=$( echo "$i" | cut -d "_" -f 2 )

    if [ "$suffix_tmp" -gt "$BORGBACKUP_SUFFIX" ]; then
        BORGBACKUP_SUFFIX=$suffix_tmp
    fi
done

BORGBACKUP_SUFFIX=$(( BORGBACKUP_SUFFIX + 1 ))
