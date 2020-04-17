# if $scheme=iso then we must have isofs module in rescue mode so that we can
# loopback mount the ISO containing the backup
# BACKUP_URL=iso://backup

local scheme=$(url_scheme $BACKUP_URL)

case "$scheme" in
    (iso)
        MODULES+=( isofs )
        ;;
esac
