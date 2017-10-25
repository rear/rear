# 380_prepare_multiple_isos
#

local scheme=$(url_scheme $BACKUP_URL)
local path=$(url_path $BACKUP_URL)
local opath=$(backup_path $scheme $path)

[[ -f "${opath}/backup.splitted" ]] || return 0

FIFO="$TMP_DIR/tar_fifo"
mkfifo $FIFO
( cat > $FIFO <&9 & echo $! > "${TMP_DIR}/cat_pid" ) 9<&0

cp "${opath}/backup.splitted" ${TMP_DIR}
cp "${backuparchive}.md5" ${TMP_DIR}/backup.md5

Log "fifo creation successful"
