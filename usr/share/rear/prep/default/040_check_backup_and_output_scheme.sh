#
# Check conditions that depend on BACKUP_URL or OUTPUT_URL
# in particular conditions that depend on their schemes.
#

if test "$BACKUP_URL" ; then
    local backup_scheme=$( url_scheme "$BACKUP_URL" )
    case $backup_scheme in
       (iso)
           case $WORKFLOW in
               (mkrescue|mkbackuponly)
                   # When the backup is configured to be in the ISO (e.g. via BACKUP_URL="iso:///mybackup")
                   # only "rear mkbackup" results an ISO (or ISOs cf. https://github.com/rear/rear/issues/1545)
                   # that is/are usable for "rear recover". When the backup is configured to be in the ISO
                   # the mkrescue workflow results an ISO without backup which lets "rear recover"
                   # fail with "ERROR: Backup archive 'backup.tar.gz' not found."
                   # cf. https://github.com/rear/rear/issues/1547 and https://github.com/rear/rear/issues/1545
                   # and the mkbackuponly workflow exits with exit code 0 but results no ISO at all
                   # cf. https://github.com/rear/rear/issues/1548
                   # so that mkrescue and mkbackuponly are forbidden for the 'iso' backup scheme:
                   Error "The $WORKFLOW workflow does not work for the BACKUP_URL scheme '$backup_scheme'"
                   ;;
           esac
           ;;
    esac
else
    # When there is no BACKUP_URL it is not mandatory in general, see in 'man rear'
    # "An example to use TSM for backup and ISO for output"
    # but BACKUP_URL is more or less mandatory in practice for BACKUP=NETFS
    # cf. https://github.com/rear/rear/issues/1532#issuecomment-336810460
    # so that we do not error out when there is no BACKUP_URL:
    test "NETFS" = $BACKUP && LogPrintError "BACKUP=NETFS usually requires a BACKUP_URL backup target location"
fi

if test "$OUTPUT_URL" ; then
    local output_scheme=$( url_scheme "$OUTPUT_URL" )
    case $output_scheme in
       (fish|ftp|ftps|hftp|http|https|sftp)
          local required_prog='lftp'
          has_binary $required_prog || Error "The OUTPUT_URL scheme '$output_scheme' requires the '$required_prog' command which is missing"
          ;;
       (iso)
          Error "The OUTPUT_URL scheme cannot be '$output_scheme'"
          ;;
    esac
fi

