# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# 200_find_duply_profile.sh

# Actually this script sources (i.e. executes) the 'duply' profile.
# The script file name is misleading because the find_duply_profile function
# can no longer be used because it is insecure to search some directories and
# then execute some found file which was not explicitly specified by the user,
# cf. https://github.com/rear/rear/issues/3293

# Nothing to do when BACKUP_PROG is not 'duplicity':
test "$BACKUP_PROG" = "duplicity" || return 0

# Nothing to do when we are not using the 'duply' wrapper for 'duplicity':
has_binary duply || return 0

# If at least one of BACKUP_DUPLICITY_URL BACKUP_DUPLICITY_NETFS_URL BACKUP_DUPLICITY_NETFS_MOUNTCMD
# is defined then we assume we are using only 'duplicity' and not the wrapper 'duply'
# cf. the same code in restore/DUPLICITY/default/110_check_temp_dir_with_duply.sh
if [[ "$BACKUP_DUPLICITY_URL" || "$BACKUP_DUPLICITY_NETFS_URL" || "$BACKUP_DUPLICITY_NETFS_MOUNTCMD" ]] ; then
    DebugPrint "Assuming 'duplicity' is used and not 'duply' because BACKUP_DUPLICITY_URL or BACKUP_DUPLICITY_NETFS_URL or BACKUP_DUPLICITY_NETFS_MOUNTCMD is set"
    return 0
fi
DebugPrint "Assuming 'duply' is used and not 'duplicity' because none of BACKUP_DUPLICITY_URL BACKUP_DUPLICITY_NETFS_URL BACKUP_DUPLICITY_NETFS_MOUNTCMD is set"

# Only an explicitly user specified DUPLY_PROFILE gets sourced
# to avoid that some automatism finds and sources whatever it may have found
# cf. https://github.com/rear/rear/pull/3345
# Accordingly error out when DUPLY_PROFILE is empty or does not exist
# to make the user aware that he must explicitly specify his correct DUPLY_PROFILE:
test -s "$DUPLY_PROFILE" || Error "DUPLY_PROFILE '$DUPLY_PROFILE' empty or does not exist (assuming 'duply' is used and not 'duplicity')"

# Check if we can talk to the remote site:
# According to the 'duply' "Manpage" on https://duply.net/Documentation
# that reads (excerpts)
#   PROFILE:
#     Indicated by a path or a profile name
#     ...
#     example 2:   duply ~/.duply/humbug backup
#     ...
#   COMMANDS:
#     ...
#     status     prints backup sets and chains currently in repository
#     ...
# the command "duply /path/to/profile status" prints backup sets and chains currently in repository
# so its stdout and stderr output appears in the ReaR logfile only in debug modes,
# cf. https://github.com/rear/rear/wiki/Coding-Style#what-to-do-with-stdin-stdout-and-stderr
DebugPrint "Checking with 'duply $DUPLY_PROFILE status' if 'duply' can talk to the remote site"
Debug "'duply $DUPLY_PROFILE status' output:"
echo yes | duply "$DUPLY_PROFILE" status || Error "'duply $DUPLY_PROFILE status' failed, check $RUNTIME_LOGFILE"

# We use 'duply' as BACKUP_PROG - so define as such (instead of BACKUP_PROG=duplicity above):
BACKUP_PROG=duply

COPY_AS_IS+=( "$DUPLY_PROFILE" )

echo "DUPLY_PROFILE=$DUPLY_PROFILE" >> "$ROOTFS_DIR/etc/rear/rescue.conf" || Error "Failed to add 'DUPLY_PROFILE=$DUPLY_PROFILE' to rescue.conf"
Log "Added 'DUPLY_PROFILE=$DUPLY_PROFILE' to rescue.conf"

DebugPrint "Sourcing '$DUPLY_PROFILE'"
source "$DUPLY_PROFILE" || Error "Failed to source $DUPLY_PROFILE"

# Check the scheme of the TARGET variable in DUPLY_PROFILE
# to ensure we have all executables we need in the rescue image.
# https://www.it3.be/2015/09/02/rear-using-duply/
# shows an example of DUPLY_PROFILE content (excerpt):
#   GPG_KEY='BD4A8DCC'
#   GPG_PW='my_secret_key_phrase'
#   TARGET='scp://root:my_secret_password@freedom//exports/archives/ubuntu-15-04'
#   SOURCE='/'
#   MAX_AGE=1M
#   MAX_FULL_BACKUPS=1
#   MAX_FULLS_WITH_INCRS=1
#   VERBOSITY=5
#   TEMP_DIR=/tmp
# Luckily ReaR uses TMP_DIR so sourcing DUPLY_PROFILE does not overwrite a ReaR variable,
# cf. https://github.com/rear/rear/issues/3259 "ReaR must not carelessly 'source' files"
local scheme="$( url_scheme "$TARGET" )"
case "$scheme" in
    (sftp|rsync|scp)
        REQUIRED_PROGS+=( "$scheme" )
esac
