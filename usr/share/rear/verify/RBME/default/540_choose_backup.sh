
scheme=$(url_scheme "$BACKUP_URL")
case $scheme in
    (local|nfs)
        :
        ;;
    (*)
        return
        ;;
esac

# Detect all backups in the specified location
backups=()
backup_times=()
for backup in $BUILD_DIR/outputfs/$RBME_HOSTNAME/????-??-?? ;do
    Debug "RBME backup $backup detected."
    backups+=( ${backup##*/} )
done

(( ${#backups[@]} > 0 ))
StopIfError "No RBME backups available."

if [[ "$RBME_BACKUP" ]] ; then
    if IsInArray "$RBME_BACKUP" "${backups[@]}" ; then
        LogPrint "Backup $RBME_BACKUP preselected."
        return
    elif [[ "$RBME_BACKUP" == "latest" ]] ; then
        ### a bash glob is alphabetically sorted
        RBME_BACKUP=${backups[${#backups[@]} - 1]}
        LogPrint "Latest backup $RBME_BACKUP selected."
        return
    else
        LogPrint "Preselected backup $RBME_BACKUP does not exist."
    fi
fi


# The user has to choose the backup
LogPrint "Select a backup to restore."
# Use the original STDIN STDOUT and STDERR when rear was launched by the user
# to get input from the user and to show output to the user (cf. _input-output-functions.sh):
select choice in "${backups[@]}" "Abort"; do
    [ "$choice" != "Abort" ]
    StopIfError "User chose to abort recovery."
    n=( $REPLY ) # trim blanks from reply
    let n-- # because bash arrays count from 0
    if [ "$n" -lt 0 ] || [ "$n" -ge "${#backups[@]}" ] ; then
        LogPrint "Invalid choice $REPLY, please try again or abort."
        continue
    fi
    LogPrint "Backup ${backups[$n]} chosen."
    RBME_BACKUP=${backups[$n]}
    break
done 0<&6 1>&7 2>&8

