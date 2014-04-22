# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

# 20_find_duply_profile.sh (use 20 as with 10 we would loose our DUPLY_PROFILE setting)

# purpose is to see we're using duply wrapper and if there is an existing profile defined
# if that is the case then we define an internal variable DUPLY_PROFILE="profile"
# the profile is in fact a directory name containing the conf file and exclude file
# we shall copy this variable, if defined, to our rescue.conf file

if [ "$BACKUP_PROG" = "duplicity" ] && has_binary duply; then

    # we found the duply program; check if we can find a profile defined
    if [[ -z "$DUPLY_PROFILE" ]]; then
        # no profile pre-set; let's try to find one
        DUPLY_PROFILE=$( find /etc/duply /root/.duply -name conf )
        [[ -z "$DUPLY_PROFILE" ]] && return

        # there could be more then one profile present - select where SOURCE='/'
        for CONF in $(echo $DUPLY_PROFILE)
        do
            source $CONF    # is a normal shell configuration file
            LogIfError "Could not source $CONF [duply profile]"
            [[ -z "$SOURCE" ]] && continue
            [[ -z "$TARGET" ]] && continue
            # still here?
            if [[ "$SOURCE" = "/" ]]; then
                DUPLY_PROFILE=$( dirname $CONF  )   # /root/.duply/mycloud/conf -> /root/.duply/mycloud
                DUPLY_PROFILE=${DUPLY_PROFILE##*/}  # /root/.duply/mycloud      -> mycloud
                break # the loop
            else
                DUPLY_PROFILE=""
                continue
            fi
        done
    fi

    # if DUPLY_PROFILE="" then we only found empty profiles
    [[ -z "$DUPLY_PROFILE" ]] && return

    # a real profile was detected - check if we can talk to the remote site
    duply "$DUPLY_PROFILE" status >&2   # output is going to logfile
    StopIfError "Duply profile $DUPLY_PROFILE status returned errors - see $LOGFILE"

    # we seem to use duply as BACKUP_PROG - so define as such too
    BACKUP_PROG=duply

    echo "DUPLY_PROFILE=$DUPLY_PROFILE" >> "$ROOTFS_DIR/etc/rear/rescue.conf"
    LogIfError "Could not add DUPLY_PROFILE variable to rescue.conf"

    LogPrint "The last full backup taken with duply/duplicity was:"
    LogPrint "$( tail -10 $LOGFILE | grep Full )"
fi

