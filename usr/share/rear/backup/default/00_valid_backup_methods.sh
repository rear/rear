VALID_BACKUP_METHODS=()
for aa in $(grep BACKUP= $SHARE_DIR/conf/default.conf | grep -v "_" | cut -d= -f2 | awk '{print $1}' | sort -u)
do
    VALID_BACKUP_METHODS=( ${VALID_BACKUP_METHODS[@]} "$aa" )
done

if ! grep -q "$BACKUP" <<< $(echo ${VALID_BACKUP_METHODS[@]}); then
    LogPrint "The BACKUP method \"$BACKUP\" is not known to rear. Use on your own risk"
fi

