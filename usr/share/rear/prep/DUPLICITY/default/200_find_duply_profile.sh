# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# 200_find_duply_profile.sh

# If $BACKUP_DUPLICITY_URL has been defined then we may assume we are using
# only 'duplicity' to make the backup and not the wrapper duply
[[ "$BACKUP_DUPLICITY_URL" || "$BACKUP_DUPLICITY_NETFS_URL" || "$BACKUP_DUPLICITY_NETFS_MOUNTCMD" ]] && return

# purpose is to see we're using duply wrapper and if there is an existing profile defined
# if that is the case then we define an internal variable DUPLY_PROFILE="profile"
# the profile is in fact a directory name containing the conf file and exclude file
# we shall copy this variable, if defined, to our rescue.conf file

if [ "$BACKUP_PROG" = "duplicity" ] && has_binary duply; then

    function find_duply_profile ()
    {
        # there could be more then one profile present - select where SOURCE='/'
        for CONF in $(echo "$1")
        do
            [[ ! -f $CONF ]] && continue
            source $CONF    # is a normal shell configuration file
            LogIfError "Could not source $CONF [duply profile]"
            [[ -z "$SOURCE" ]] && continue
            [[ -z "$TARGET" ]] && continue
            # still here?
            if [[ "$SOURCE" = "/" ]]; then
                DUPLY_PROFILE_FILE=$CONF
                DUPLY_PROFILE=$( dirname $CONF  )   # /root/.duply/mycloud/conf -> /root/.duply/mycloud
                DUPLY_PROFILE=${DUPLY_PROFILE##*/}  # /root/.duply/mycloud      -> mycloud
                break # the loop
            else
                DUPLY_PROFILE=""
                continue
            fi
        done
    }

    # we found the duply program; check if we can find a profile defined in ReaR config file
    if [[ -z "$DUPLY_PROFILE" ]]; then
        # no profile pre-set in local.conf; let's try to find one
        DUPLY_PROFILE=$( find /etc/duply /root/.duply -name conf 2>&1)
        # above result could contain more than one profile
        [[ -z "$DUPLY_PROFILE" ]] && return
        find_duply_profile "$DUPLY_PROFILE"
    fi

    # if DUPLY_PROFILE="" then we only found empty profiles
    [[ -z "$DUPLY_PROFILE" ]] && return

    # retrieve the real path of DUPLY_PROFILE in case DUPLY_PROFILE was defined local.conf
    DUPLY_PROFILE_FILE=$( ls /etc/duply/$DUPLY_PROFILE/conf /root/.duply/$DUPLY_PROFILE/conf 2>/dev/null )
    # Assuming we have a duply configuration we must have a path, right?
    [[ -z "$DUPLY_PROFILE_FILE" ]] && return
    find_duply_profile "$DUPLY_PROFILE_FILE"

    # a real profile was detected - check if we can talk to the remote site
    echo yes | duply "$DUPLY_PROFILE" status >&2   # output is going to logfile
    StopIfError "Duply profile $DUPLY_PROFILE status returned errors - see $RUNTIME_LOGFILE"

    # we seem to use duply as BACKUP_PROG - so define as such too
    BACKUP_PROG=duply

    echo "DUPLY_PROFILE=$DUPLY_PROFILE" >> "$ROOTFS_DIR/etc/rear/rescue.conf"
    LogIfError "Could not add DUPLY_PROFILE variable to rescue.conf"

    LogPrint "The last full backup taken with duply/duplicity was:"
    LogPrint "$( tail -50 $RUNTIME_LOGFILE | grep 'Last full backup date:' )"

    # check the scheme of the TARGET variable in DUPLY_PROFILE ($CONF has full path)  to be
    # sure we have all executables we need in the rescue image
    source $DUPLY_PROFILE_FILE
    local scheme=$( url_scheme $TARGET )
    case $scheme in
       (sftp|rsync|scp)
           PROGS=( "${PROGS[@]}" $scheme )
    esac
fi

