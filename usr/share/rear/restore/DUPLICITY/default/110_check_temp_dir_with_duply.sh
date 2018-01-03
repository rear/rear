# 210_check_temp_dir_with_duply.sh

# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# If $BACKUP_DUPLICITY_URL has been defined then we may assume we are using
# only 'duplicity' to make the backup and not the wrapper duply
[[ "$BACKUP_DUPLICITY_URL" || "$BACKUP_DUPLICITY_NETFS_URL" || "$BACKUP_DUPLICITY_NETFS_MOUNTCMD" ]] && return

# if DUPLY_PROFILE="" then we have nonsense defined in our ReaR configuration
[[ -z "$DUPLY_PROFILE" ]] && return

DUPLY_PROFILE_FILE=$( ls /etc/duply/$DUPLY_PROFILE/conf /root/.duply/$DUPLY_PROFILE/conf 2>/dev/null )
# Assuming we have a duply configuration we must have a path, right?
[[ -z "$DUPLY_PROFILE_FILE" ]] && return
find_duply_profile "$DUPLY_PROFILE_FILE"

[[ ! -d $TARGET_FS_ROOT ]] && return  # must be recreated and mounted

# We need $TARGET_FS_ROOT/tmp as temp dir during the duplicity recovery (where we have enough space)
[[ ! -d $TARGET_FS_ROOT/tmp ]] && mkdir -m 1777 $TARGET_FS_ROOT/tmp

# Now we are coming to the real task of this script and that is verifying the setting of TEMP_DIR in
# the conf file and make sure that the TEMP_DIR is set to /mnt/local/tmp instead of /tmp
# If the TEMP_DIR was already different we will *not* modify it
if grep -q "^TEMP_DIR=/tmp" "$DUPLY_PROFILE_FILE" ; then
    sed -i -e "s|TEMP_DIR=/tmp|TEMP_DIR=$TARGET_FS_ROOT/tmp|" "$DUPLY_PROFILE_FILE"
else
    # no variable found which means /tmp is used. We will define one for the restore sake.
    echo "TEMP_DIR=$TARGET_FS_ROOT/tmp" >> "$DUPLY_PROFILE_FILE"
fi
