# 210_check_temp_dir_with_duply.sh

# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# If at least one of BACKUP_DUPLICITY_URL BACKUP_DUPLICITY_NETFS_URL BACKUP_DUPLICITY_NETFS_MOUNTCMD
# is defined then we assume we are using only 'duplicity' and not the wrapper 'duply'
# cf. the same code in prep/DUPLICITY/default/200_find_duply_profile.sh
if [[ "$BACKUP_DUPLICITY_URL" || "$BACKUP_DUPLICITY_NETFS_URL" || "$BACKUP_DUPLICITY_NETFS_MOUNTCMD" ]] ; then
    DebugPrint "Assuming 'duplicity' is used and not 'duply' because BACKUP_DUPLICITY_URL or BACKUP_DUPLICITY_NETFS_URL or BACKUP_DUPLICITY_NETFS_MOUNTCMD is set"
    return 0
fi
DebugPrint "Assuming 'duply' is used and not 'duplicity' because none of BACKUP_DUPLICITY_URL BACKUP_DUPLICITY_NETFS_URL BACKUP_DUPLICITY_NETFS_MOUNTCMD is set"

# It is OK to error out after the disk layout was recreated but before the backup is restored
# because during "rear recover" the most time consuming part is usually the backup restore
# cf. the same test in prep/DUPLICITY/default/200_find_duply_profile.sh
test -s "$DUPLY_PROFILE" || Error "DUPLY_PROFILE '$DUPLY_PROFILE' empty or does not exist (assuming 'duply' is used and not 'duplicity')"

# This error should never happen here because
# layout/recreate/default/250_verify_mount.sh
# should already error out in this case:
test -d "$TARGET_FS_ROOT" || Error "No TARGET_FS_ROOT '$TARGET_FS_ROOT' directory"

# We need $TARGET_FS_ROOT/tmp as temp dir during the duplicity backup restore (where we have enough space).
# FIXME: Hopefully "mkdir -m 1777 $TARGET_FS_ROOT/tmp" is OK because it creates the /tmp directory 
# with the usual /tmp directory owner group and permissions "drwxrwxrwt root root" in the target system.
# But normally "rear recover" should not recreate a system different than it was before.
# So hopefully the backup contains the /tmp directory so that it would get restored
# exactly as it was on the original system (might be different than "drwxrwxrwt root root").
test -d "$TARGET_FS_ROOT/tmp" || mkdir -m 1777 "$TARGET_FS_ROOT/tmp"

# The main task of this script is to verify the setting of TEMP_DIR in DUPLY_PROFILE:
if grep -q "^TEMP_DIR=" "$DUPLY_PROFILE" ; then
    # When TEMP_DIR is /tmp then change it to /mnt/local/tmp
    # but if TEMP_DIR is specified different (i.e. not /tmp but e.g. /tmp/duply) we keep it as is
    # (regardless that with e.g. TEMP_DIR=/tmp/duply the duplicity backup restore likely fails
    # because normally there is no /tmp/duply directory in the ReaR recovery system):
    if grep -q "^TEMP_DIR=/tmp$" "$DUPLY_PROFILE" ; then
        sed -i -e "s|TEMP_DIR=/tmp|TEMP_DIR=$TARGET_FS_ROOT/tmp|" "$DUPLY_PROFILE"
    fi
else
    # No TEMP_DIR variable is set in DUPLY_PROFILE which means /tmp would be used
    # so we specify TEMP_DIR in DUPLY_PROFILE as we need it for the restore:
    echo "TEMP_DIR=$TARGET_FS_ROOT/tmp" >> "$DUPLY_PROFILE"
fi
