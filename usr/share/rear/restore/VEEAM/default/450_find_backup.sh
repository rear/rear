#!/bin/bash

# Find ID of latest backup

# TODO: Support point-in-time restore similar to GALAXY11

local backuplist
LogPrint "Query the latest full backup for Veeam client: $(hostname)"
# output of veeamconfig backup list looks like this:
# Job name Backup ID Repository Created at
# Linux_FS_nosnap_01 - rhel8-veeam02.lab.quorum.at {62749ef7-970a-4ff9-89b9-134bc276a1e6} [qlveeam11] Default Backup Repository 2024-01-15 18:07
# Linux_FS_nosnap_02 - rhel8-veeam02.lab.quorum.at {27c3120b-ae5f-4086-b508-10c49489c06a} [qlveeam11] Default Backup Repository 2024-01-15 20:59
# Linux_FS_nosnap_02 - rhel8-veeam02.lab.quorum.at {a28896fb-61bc-4ed9-9b30-5801a6eb5698} [qlveeam11] Default Backup Repository 2024-01-15 22:05

backuplist=$(veeamconfig backup list --all | grep " - $HOSTNAME") || Error "Failed to query backup list" # search for short HOSTNAME, also to match the fqdn
[[ "$backuplist" == *{* ]] || Error "Backup list doesn't contain any backups:$LF$backuplist"

VEEAM_BACKUPID=$(sed -n -e '$s/^.*\({.*}\).*$/\1/p' <<<"$backuplist") # pick backup ID {...} from last line. We assume that the last line is the most recent backup

test "$VEEAM_BACKUPID" || Error "Could not determine backup ID from backup list:$LF$backuplist"
