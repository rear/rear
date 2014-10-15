# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

if [ "$BACKUP_PROG" = "duply" ] && has_binary duply; then
    # we found the duply program; check if a profile was defined
    [[ -z "$DUPLY_PROFILE" ]] && return

    # a real profile was detected - check if we can talk to the remote site
    LogPrint "Starting full backup with duply/duplicity"
    duply "$DUPLY_PROFILE" backup >&2   # output is going to logfile
    StopIfError "Duply profile $DUPLY_PROFILE backup returned errors - see $LOGFILE"

    LogPrint "The last full backup taken with duply/duplicity was:"
    LogPrint "$( tail -50 $LOGFILE | grep 'Last full backup date:' )"
fi


if [ "$BACKUP_PROG" = "duplicity" ]; then

    # make backup using the DUPLICITY method with duplicity
    # by falk hoeppner 
    
    LogPrint "Creating $BACKUP_PROG archives on '$BACKUP_DUPLICITY_URL'"
    
    # using some new parameters from config.local 
    #
    # DUPLICITY_USER
    # DUPLICITY_HOST
    # DUPLICITY_PROTO
    # DUPLICITY_PATH
    # BACKUP_DUPLICITY_URL
    
    if [ -n $DUPLICITY_USER -a -n $DUPLICITY_HOST -a -n $DUPLICITY_PROTO -a -n $DUPLICITY_PATH ]
    then 
        BKP_URL="$BACKUP_DUPLICITY_URL"
        # ToDo: do some more plausibility checks !?
    else
        Error "Parameters for BACKUP_DUPLICITY_URL not set correctly, please look at config.local template"
    fi
    
    # todo: check parameters
    DUP_OPTIONS="$BACKUP_DUPLICITY_OPTIONS"
    #
    GPG_OPT="${BACKUP_DUPLICITY_GPG_OPTIONS}"
    GPG_KEY="$BACKUP_DUPLICITY_GPG_ENC_KEY"
    PASSPHRASE="$BACKUP_DUPLICITY_GPG_ENC_PASSPHRASE"

    echo "GPG_OPT = $GPG_OPT"
    
    # EXCLUDES="${TMP_DIR}/backup_exclude.lst"

    # NMBRS=${#BACKUP_DUPLICITY_EXCLUDE[$@]}
    # echo NMBRS = $NMBRS

    # for i in $(seq 0 $(($NMBRS - 1)) )
    # do
    #     LogPrint "Exclude No $i = ${BACKUP_DUPLICITY_EXCLUDE[$i]}"
    #     echo "${BACKUP_DUPLICITY_EXCLUDE[$i]}" >> "${EXCLUDES}"
    # done

    # runs without external file, but all the * in the excludelist 
    # will expanded :-(
    #
    for EXDIR in ${BACKUP_DUPLICITY_EXCLUDE[@]}
    do
        EXCLUDES="$EXCLUDES --exclude $EXDIR"
    done

    echo EXCLUDES = $EXCLUDES
    
    # Setting the pass phrase to encrypt the backup files
    export PASSPHRASE
    
    # check and create directory at backup-server
    # if the target-directory dont exist, duplicity will fail
    # Note: this is only working if we use duplicity with ssh/rsync and the 
    # given user is allowed to create directories/files this way !!
    # maybe better done in an if or case statment
    #
    LogPrint "Checking backup-path at server ..."
    ssh ${DUPLICITY_USER}@${DUPLICITY_HOST} "test -d ${DUPLICITY_PATH}/${HOSTNAME} || mkdir -p ${DUPLICITY_PATH}/${HOSTNAME}"
    
    # first remove everything older than $BACKUP_DUPLICITY_MAX_TIME
    if [ -z $BACKUP_DUPLICITY_MAX_TIME ]
    then
        BACKUP_DUPLICITY_MAX_TIME=2M  # Default: alte Backups nach 2 Monaten löschen
    fi
    LogPrint "Removing the old stuff from server with CMD:
    $DUPLICITY_PROG remove-older-than $BACKUP_DUPLICITY_MAX_TIME -v5 $BKP_URL/$HOSTNAME"
    $DUPLICITY_PROG remove-older-than $BACKUP_DUPLICITY_MAX_TIME -v5 $BKP_URL/$HOSTNAME >> ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log
    
    # do the backup
    LogPrint "Running CMD: $DUPLICITY_PROG -v5 $DUP_OPTIONS --encrypt-key $GPG_KEY $GPG_OPT $EXCLUDES \
     / $BKP_URL/$HOSTNAME >> ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log "
    $DUPLICITY_PROG -v5 $DUP_OPTIONS --encrypt-key $GPG_KEY $GPG_OPT $EXCLUDES \
           / $BKP_URL/$HOSTNAME >> ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log 2>&1
    
    RC_DUP=$?
    
    sleep 1
    LOGAUSZUG=$(tail -n 18 ${TMP_DIR}/${BACKUP_PROG_ARCHIVE}.log)
    LogPrint "${LOGAUSZUG}"

    # everyone should see this warning, even if not verbose
    if [ $RC_DUP -gt 0 ] 
    then 
        VERBOSE=1
        LogPrint "WARNING !
    There was an error during archive creation.
    Please check the archive and see '$LOGFILE' for more information.
    
    Since errors are oftenly related to files that cannot be saved by
    $BACKUP_PROG, we will continue the $WORKFLOW process. However, you MUST
    verify the backup yourself before trusting it !
    "
        LogPrint "$LOGAUSZUG"
    fi
fi

