# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

if [ "$BACKUP_PROG" = "duply" ] && has_binary duply ; then
    # we found the duply program; check if a profile was defined
    [[ -z "$DUPLY_PROFILE" ]] && return

    # a real profile was detected - check if we can talk to the remote site
    LogPrint "Starting full backup with duply/duplicity"
    duply "$DUPLY_PROFILE" backup >&2   # output is going to logfile
    StopIfError "Duply profile $DUPLY_PROFILE backup returned errors - see $RUNTIME_LOGFILE"

    LogPrint "The last full backup taken with duply/duplicity was:"
    LogPrint "$( tail -50 $RUNTIME_LOGFILE | grep 'Last full backup date:' )"
fi


if [ "$BACKUP_PROG" = "duplicity" ] ; then

    # make backup using the DUPLICITY method with duplicity
    # by falk hoeppner

    if is_true "$BACKUP_DUPLICITY_ASK_PASSPHRASE"; then
        LogPrint "Duplicity passphrase must be provided interactively on restore (BACKUP_DUPLICITY_ASK_PASSPHRASE is set)"
    fi

    LogPrint "Creating $BACKUP_PROG archives on '$BACKUP_DUPLICITY_URL'"

    # todo: check parameters
    BKP_URL="$BACKUP_DUPLICITY_URL"

    DUP_OPTIONS="$BACKUP_DUPLICITY_OPTIONS"

    if [ -n "$BACKUP_DUPLICITY_FULL_IF_OLDER_THAN" ]; then
        FULL_BACKUP="--full-if-older-than $BACKUP_DUPLICITY_FULL_IF_OLDER_THAN"
    fi

    if [ -n "$BACKUP_DUPLICITY_GPG_ENC_KEY" ]; then
        GPG_KEY="--encrypt-key $BACKUP_DUPLICITY_GPG_ENC_KEY"
    fi
    PASSPHRASE="$BACKUP_DUPLICITY_GPG_ENC_PASSPHRASE"

    if ! is_true "$BACKUP_DUPLICITY_EXCLUDE_EVALUATE_BY_SHELL"; then
        set -f # Temporarily Stop Evaluation of Patterns By the Shell
    fi
    # Disable SC2068: "Double quote array expansions to avoid re-splitting elements."
    # because whether or not "Evaluation of Patterns By the Shell" (globbing) happens
    # is controlled by BACKUP_DUPLICITY_EXCLUDE_EVALUATE_BY_SHELL
    # shellcheck disable=SC2068
    for EXDIR in ${BACKUP_DUPLICITY_EXCLUDE[@]} ; do
        EXCLUDES+=" --exclude $EXDIR"
    done
    if ! is_true "$BACKUP_DUPLICITY_EXCLUDE_EVALUATE_BY_SHELL"; then
        set +f # Reenable Evaluation of Patterns By the Shell
    fi

    LogUserOutput "EXCLUDES = $EXCLUDES"

    # Setting the pass phrase to encrypt the backup files
    export PASSPHRASE

    # check and create directory at backup-server
    # if the target-directory don't exist, duplicity will fail
    # Note: this is only working if we use duplicity with ssh/rsync and the
    # given user is allowed to create directories/files this way !!
    # maybe better done in an if or case statement
    #
    if [[ $BKP_URL == ssh://* ]] || [[ $BKP_URL == rsync://* ]] || [[ $BKP_URL == fish://* ]] ; then
        LogPrint "Checking backup-path at server ..."
        ssh ${DUPLICITY_USER}@${DUPLICITY_HOST} "test -d ${DUPLICITY_PATH}/${HOSTNAME} || mkdir -p ${DUPLICITY_PATH}/${HOSTNAME}"
    fi

    # First remove old Backups
    # --force Is needed to actually remove them
    if [ -n "$BACKUP_DUPLICITY_MAX_SETS" ] ; then
        LogPrint "Removing the old Backups from the Server with CMD:
    $DUPLICITY_PROG remove-all-but-n-full --name $BACKUP_DUPLICITY_NAME --force $BACKUP_DUPLICITY_MAX_SETS -v5 $BKP_URL/$HOSTNAME"
        $DUPLICITY_PROG remove-all-but-n-full --name $BACKUP_DUPLICITY_NAME --force $BACKUP_DUPLICITY_MAX_SETS -v5 $BKP_URL/$HOSTNAME >> ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log
    fi

    if [ -n "$BACKUP_DUPLICITY_MAX_SETS_KEEP_FULL" ] ; then
        LogPrint "Removing the old Backups from the Server with CMD:
    $DUPLICITY_PROG remove-all-inc-of-but-n-full --name $BACKUP_DUPLICITY_NAME --force $BACKUP_DUPLICITY_MAX_SETS_KEEP_FULL -v5 $BKP_URL/$HOSTNAME"
        $DUPLICITY_PROG remove-all-inc-of-but-n-full --name $BACKUP_DUPLICITY_NAME --force $BACKUP_DUPLICITY_MAX_SETS_KEEP_FULL -v5 $BKP_URL/$HOSTNAME >> ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log
    fi

    if [ -n "$BACKUP_DUPLICITY_MAX_TIME" ] ; then
        LogPrint "Removing the old Backups from the Server with CMD:
    $DUPLICITY_PROG remove-older-than --name $BACKUP_DUPLICITY_NAME --force $BACKUP_DUPLICITY_MAX_TIME -v5 $BKP_URL/$HOSTNAME"
        $DUPLICITY_PROG remove-older-than --name $BACKUP_DUPLICITY_NAME --force $BACKUP_DUPLICITY_MAX_TIME -v5 $BKP_URL/$HOSTNAME >> ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log
    fi

    if ! is_true "$BACKUP_DUPLICITY_EXCLUDE_EVALUATE_BY_SHELL"; then
        set -f # Temporarily Stop Evaluation of Patterns By the Shell
    fi

    # do the backup
    if [[ "$BACKUP_DUPLICITY_GPG_OPTIONS" ]] ; then
        LogPrint "Running CMD: $DUPLICITY_PROG -v5 --name $BACKUP_DUPLICITY_NAME $FULL_BACKUP $DUP_OPTIONS $GPG_KEY --gpg-options ${BACKUP_DUPLICITY_GPG_OPTIONS} $EXCLUDES / $BKP_URL/$HOSTNAME >> ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log "
        $DUPLICITY_PROG -v5 --name $BACKUP_DUPLICITY_NAME $FULL_BACKUP $DUP_OPTIONS $GPG_KEY --gpg-options "${BACKUP_DUPLICITY_GPG_OPTIONS}" $EXCLUDES \
           / $BKP_URL/$HOSTNAME >> ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log 2>&1
    else
        LogPrint "Running CMD: $DUPLICITY_PROG -v5 --name $BACKUP_DUPLICITY_NAME $FULL_BACKUP $DUP_OPTIONS $GPG_KEY $EXCLUDES / $BKP_URL/$HOSTNAME >> ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log "
        $DUPLICITY_PROG -v5 --name $BACKUP_DUPLICITY_NAME $FULL_BACKUP $DUP_OPTIONS $GPG_KEY $EXCLUDES \
           / $BKP_URL/$HOSTNAME >> ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log 2>&1
    fi

    if ! is_true "$BACKUP_DUPLICITY_EXCLUDE_EVALUATE_BY_SHELL"; then
        set +f # Reenable Evaluation of Patterns By the Shell
    fi

    RC_DUP=$?

    sleep 1
    LOGAUSZUG=$(tail -n 18 ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log)
    LogPrint "${LOGAUSZUG}"

    # everyone should see this warning, even if not verbose
    if [ $RC_DUP -gt 0 ] ; then
        VERBOSE=1
        LogPrint "WARNING !
    There was an error during archive creation.
    Please check the archive and see '$RUNTIME_LOGFILE' for more information.

    Since errors are often related to files that cannot be saved by
    $BACKUP_PROG, we will continue the $WORKFLOW process. However, you MUST
    verify the backup yourself before trusting it !
    "
        LogPrint "$LOGAUSZUG"
    fi
fi

