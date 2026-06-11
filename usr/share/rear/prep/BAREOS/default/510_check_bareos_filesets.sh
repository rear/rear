# 560_check_bareos_filesets.sh

# Select a fileset, for which at least a backup exists for this client.
# Alternatively, BAREOS_FILESET can be set in the config file.

# Get extended list (llist, long list) of backups for a specific client.
# This description also contains the used fileset.
# Example:
#
# bcommand "llist backups client=client1"
#            jobid: 3
#              job: backup-client1.2024-05-29_16.03.47_08
#             name: backup-client1
#      purgedfiles: 0
#             type: B
#            level: F
#         clientid: 2
#           client: client1
#        jobstatus: T
#        schedtime: 2024-05-29 16:03:46
#        starttime: 2024-05-29 16:03:49
#          endtime: 2024-05-29 16:05:34
#      realendtime: 2024-05-29 16:05:34
#         duration: 00:01:45
#         jobtdate: 1,716,998,734
#     volsessionid: 3
#   volsessiontime: 1,716,996,683
#         jobfiles: 43,785
#         jobbytes: 2,007,335,334
#        joberrors: 0
#  jobmissingfiles: 0
#           poolid: 3
#         poolname: Full
#       priorjobid: 0
#        filesetid: 2
#          fileset: LinuxAll
# 
#            jobid: 4
#              job: backup-client1.2024-05-29_16.41.30_21
#             name: backup-client1
#      purgedfiles: 0
#             type: B
#            level: I
#         clientid: 2
#           client: client1
#        jobstatus: T
#        schedtime: 2024-05-29 16:41:28
#        starttime: 2024-05-29 16:41:32
#          endtime: 2024-05-29 16:41:35
#      realendtime: 2024-05-29 16:41:35
#         duration: 00:00:03
#         jobtdate: 1,717,000,895
#     volsessionid: 4
#   volsessiontime: 1,716,996,683
#         jobfiles: 2,792
#         jobbytes: 310,942,237
#        joberrors: 0
#  jobmissingfiles: 0
#           poolid: 2
#         poolname: Incremental
#       priorjobid: 0
#        filesetid: 2
#          fileset: LinuxAll

mapfile -t filesets < <( bcommand "llist backups client=$BAREOS_CLIENT" | bcommand_extract_value "fileset" | sort | uniq )

Log "available filesets:" "${filesets[@]}"

if (( ${#filesets[@]} == 0 )); then
    Error "No valid backups found for client $BAREOS_CLIENT"
fi

if [ "$BAREOS_FILESET" ]; then
    if ! IsInArray "$BAREOS_FILESET" "${filesets[@]}"; then
        Error "No valid backup for fileset ($BAREOS_FILESET). Successful backups for following filesets: " "{filesets[@]}"
    fi
    return
fi

if (( ${#filesets[@]} == 1 )); then
    BAREOS_FILESET="${filesets[0]}"
    {
        echo "# added by prep/BAREOS/default/560_check_bareos_filesets.sh"
        echo "BAREOS_FILESET=$BAREOS_FILESET"
        echo
    } >> "$ROOTFS_DIR/etc/rear/rescue.conf"
    LogPrint "Using '$BAREOS_FILESET' as BAREOS_FILESET. For automatic restore, recreate the rescue image when changing the clients fileset."
    return
fi

Error "Could not determine which restore fileset to use, no BAREOS_FILESET specified."
