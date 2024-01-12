# query backup server and assemble list of backup IDs and assets (= filesystems) to restore

# ddfsadmin backup query -remote -d 192.168.1.30 -s Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4 -u Linux-ppdm-01-f3392
# Querying the backup list for host: linux-03.demo.local

# Querying backup details for all assets.

# SSID        Level  DD_USERNAME          Storage Unit                                                      DD_IP         Size (Bytes)  Asset Name  Backup Time
# 1705521615  incr   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  262335339     /boot       Wed Jan 17 20:00:15 2024
# 1705521614  incr   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  6023773979    /           Wed Jan 17 20:00:14 2024
# 1705435217  incr   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  262335339     /boot       Tue Jan 16 20:00:17 2024
# 1705435215  incr   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  5852422723    /           Tue Jan 16 20:00:15 2024
# 1705417190  incr   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  262335339     /boot       Tue Jan 16 14:59:50 2024
# 1705417189  incr   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  5831305970    /           Tue Jan 16 14:59:49 2024
# 1705348833  incr   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  262138986     /boot       Mon Jan 15 20:00:33 2024
# 1705348832  incr   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  7628248368    /           Mon Jan 15 20:00:32 2024
# 1705262444  incr   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  262138986     /boot       Sun Jan 14 20:00:44 2024
# 1705262443  incr   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  7616441368    /           Sun Jan 14 20:00:43 2024
# 1705176026  incr   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  262138986     /boot       Sat Jan 13 20:00:26 2024
# 1705176025  incr   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  7605015445    /           Sat Jan 13 20:00:25 2024
# 1705089640  incr   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  262138986     /boot       Fri Jan 12 20:00:40 2024
# 1705089639  incr   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  7585073684    /           Fri Jan 12 20:00:39 2024
# 1705003240  incr   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  134429841     /boot       Thu Jan 11 20:00:40 2024
# 1705003239  incr   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  6638124606    /           Thu Jan 11 20:00:39 2024
# 1704960222  full   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  134429841     /boot       Thu Jan 11 08:03:42 2024
# 1704960221  full   Linux-ppdm-01-f3392  /Linux-ppdm-01-f3392/PLCTLP-580da36a-9e5d-4bc3-a438-d7d43cf34da4  192.168.1.30  6583641779    /           Thu Jan 11 08:03:41 2024

# How it works:
# We read the backup query output line by line and store the SSID for every Asset Name ONCE. That gives us the
# most recent SSID for every Asset Name and we use that to restore the filesystems.
#
# For point-in-time recovery we simply skip all lines where the Backup Time is newer that the PIT time. If a user
# happens to choose a PIT time that falls between the backup times of the different file systems on the same server,
# then it can happen that a PIT recovery can use different backup job runs for different filesystems. For example here,
# if the PIT would be Wed Jan 17 20:00:14 2024 then / would be restored from Wed Jan 17 20:00:14 2024 and /boot from
# Tue Jan 16 20:00:17 2024. We think that this is the best that we can do for PPDM given the available information.
#
# The benefit of this approach is that we will also be able to restore a file system that was NOT backed up
# with the last backup run, but only a previous one (e.g. /web didn't work yesterday night but the night before)
#
# The danger of this approach is that ReaR would also restore file systems that have been removed from a server,
# and this can of course make the recovery fail if there is not enough disk space available for it.
#
# We believe that the latter case will happen much more seldom and that the benefit of restoring a file system
# that wasn't saved in the latest backup run by far outweighs the danger.

local res backup_info pit_timestamp header=1 # start from parsing the header

res=$(ddfsadmin backup query -remote -d "$PPDM_DD_IP" -s "$PPDM_STORAGE_UNIT" -u "$PPDM_DD_USERNAME" 2>&1) ||
    Error "Could not query PPDM backups:$LF$res"
Debug "ddfsadmin backup query result:$LF$res"

PPDM_ASSETS_AND_SSIDS=()

pit_timestamp=$(date -d "$PPDM_RESTORE_PIT" +%s) || BugError "Could not convert PPDM_RESTORE_PIT ($PPDM_RESTORE_PIT) to timestamp"

while read -r line; do
    Debug "Parsing $line"
    if ((header == 1)); then
        # read and skip header content before table
        if [[ "$line" == *SSID*DD_USERNAME*Asset* ]]; then
            let header=0
            backup_info="Will restore the following backup sets:$LF$line"
        fi
    else
        # all following lines are content
        read ssid level dd_username storage_unit dd_ip size asset_name backup_time <<<"$line"

        # filter out all lines that have a newer backup_time than our PIT time (which defaults to "now")
        local backup_timestamp=$(date -d "$backup_time" +%s)
        if ((backup_timestamp > pit_timestamp)); then
            Log "Skipping over backup of $asset_name from $backup_time to honor PIT $PPDM_RESTORE_PIT"
            continue
        fi

        if IsInArray "$asset_name" "${!PPDM_ASSETS_AND_SSIDS[@]}"; then
            Debug "Skipping extra backup for $asset_name:$LF$line"
        else
            PPDM_ASSETS_AND_SSIDS[$asset_name]="$ssid"
            backup_info+="$LF$line"
        fi
    fi
done <<<"$res"

((${#PPDM_ASSETS_AND_SSIDS[*]} == 0)) && Error "Could not find any backup sets to recover in ddfsadmin backup query output:$LF$res"

LogPrint "$backup_info$LF"
