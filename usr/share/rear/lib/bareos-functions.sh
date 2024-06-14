#
# Bareos helper functions.
#

#
# helper functions for easier handling bconsole output
# (remove irrelevant parts of the output).
#
function bcommand()
{
  local out
  out=$(mktemp)
  (
    for i in "${BCOMMAND_PRE_COMMANDS[@]}"; do
        echo "$i"
    done
    echo "@tee $out"
    for i in "$@"; do
        echo "$i"
    done
  ) | bconsole > /tmp/bconsole.$!
  rc=$?
  # BCOMMAND_PRE_COMMANDS have been executed
  # and are therefore unset.
  unset BCOMMAND_PRE_COMMANDS

  # remove submitted commands from output.
  local sed_args="(You have messages."
  for i in "$@"; do
    sed_args+="|$i"
  done
  sed_args+=")"

  sed -r -e "/^${sed_args}$/d" -e "s/${sed_args}$//" < "$out"
  rm "$out"
  return $rc
}

function bcommand_json()
{
  BCOMMAND_PRE_COMMANDS=( ".api json compact=no" )
  bcommand "$@"
  unset BCOMMAND_PRE_COMMANDS
  return $?
}

function bcommand_extract_value()
{
  local key="$1"
  local sed_arg
  sed_arg="$(printf 's/^ *%s: (.*) *$/\\1/p' "$key")"
  sed -n -r "${sed_arg}"
}

function bcommand_check_client_status()
{
    local client="$1"

    LogPrint "Connecting to the Bareos Director ..."

    [ "$client" ] || Error "No client name given"

    # With
    # bconsole <<< "status client=$client"
    # the local command bconsole first connects to the configured Bareos Director.
    # The Bareos Director then connects to the client,
    # asks for the status and sends the output back.
    # When both systems are reachable, the output looks similar to following:
    #
    # Connecting to Director 192.168.121.219:9101
    #  Encryption: TLS_CHACHA20_POLY1305_SHA256 TLSv1.3
    # 1000 OK: bareos-dir Version: 23.0.3~pre135.a9e3d95ca (28 May 2024)
    # Bareos community build (UNSUPPORTED).
    # Get professional support from https://www.bareos.com
    # You are logged in as: operator
    #
    # Enter a period (.) to cancel a command.
    # *status client=client1-fd
    # Connecting to Client client1-fd at 192.168.121.253:9102
    # Probing client protocol... (result will be saved until config reload)
    #  Handshake: Immediate TLS, Encryption: TLS_CHACHA20_POLY1305_SHA256 TLSv1.3
    #
    # debian11-fd Version: 21.1.10 (04 June 2024)  Debian GNU/Linux 11 (bullseye)
    # Daemon started 13-Jun-24 08:50. Jobs: run=0 running=0, Bareos subscription binary
    #  Sizeof: boffset_t=8 size_t=8 debug=0 trace=0 bwlimit=0kB/s
    #
    # Running Jobs:
    # bareos-dir (director) connected at: 13-Jun-24 13:41
    # No Jobs running.
    # ====
    #
    # Terminated Jobs:
    #  JobId  Level    Files      Bytes   Status   Finished        Name 
    # ======================================================================
    #     18  Full     59,653    2.504 G  OK       05-Jun-24 14:00 backup-client1
    # ====

    # When bconsole can't access the Bareos Director, it exits with an error code.
    # When the Director does not know the client, it prints an error message and no "Connecting to Client".
    # When the Director knows about the client, but can't reach it,
    # the "Running Jobs:" text does not appear.
    # The "Running Jobs:" headline even shown when no jobs are running.
    # In this case, the additional sentence "No Jobs running." is added.

    local rc
    local bconsole_client_status
    bconsole_client_status=$(bconsole <<< "status client=$client")
    rc=$?
    if [ $rc -eq 0 ]; then
        Log "${bconsole_client_status}"
    else
        LogPrint "${bconsole_client_status}"
        Error "Failed to connect to Bareos Director."
    fi
    LogPrint "Connecting to the Bareos Director: OK"

    if ! grep "Connecting to Client $client" <<< "$bconsole_client_status"; then
        Error "Failure: The Bareos Director cannot connect to the local filedaemon ($client)."
    fi

    if ! grep "Running Jobs:" <<< "${bconsole_client_status}"; then
        Error "Failure: The Bareos Director cannot connect to the local filedaemon ($client)."
    fi

    LogPrint "Bareos Director: can connect to the local filedaemon ($client)"
}

function get_available_restore_job_names()
{
    # example output of 'bcommand_json "show jobs"':
    # {
    #   "jsonrpc": "2.0",
    #   "id": null,
    #   "result": {
    #     "jobs": {
    #       "RestoreFiles": {
    #         "name": "RestoreFiles",
    #         "type": "Restore",
    #         "fileset": "LinuxAll",
    #         "where": "/tmp/bareos-restores",
    #         "jobdefs": "DefaultJob"
    #       },
    #       "backup-bareos-fd": {
    #         "name": "backup-bareos-fd",
    #         "client": "bareos-fd",
    #         "jobdefs": "DefaultJob"
    #       }
    #     }
    #   }
    # }
    local show_jobs
    show_jobs="$( bcommand_json "show jobs" )"
    jq --exit-status --raw-output '.result.jobs | with_entries(select(.value.type == "Restore")) | .[].name' <<< "$show_jobs"
}

function get_last_restore_jobid()
{
    # example output of 'bcommand_json "list jobs client=client1-fd jobtype=R last"':
    # {
    #   "jsonrpc": "2.0",
    #   "id": null,
    #   "result": {
    #     "jobs": [
    #       {
    #         "jobid": "59",
    #         "name": "RestoreFiles",
    #         "client": "client1-fd",
    #         "starttime": "2024-06-14 10:30:06",
    #         "duration": "00:00:28",
    #         "type": "R",
    #         "level": "F",
    #         "jobfiles": "59653",
    #         "jobbytes": "2504969851",
    #         "jobstatus": "T"
    #       }
    #     ],
    #     "meta": {
    #       "range": {
    #         "filtered": 0
    #       }
    #     }
    #   }
    # }
    local bcommand_result
    bcommand_result=$( bcommand_json "list jobs ${RESTOREJOB_AS_JOB} client=$BAREOS_CLIENT jobtype=R last" )
    jq --exit-status --raw-output '.result.jobs[].jobid' <<< "$bcommand_result"
}

function get_jobid_exitcode()
{
    local jobid="$1"
    # example output of 'bcommand_json "list jobid=56"':
    # {
    #   "jsonrpc": "2.0",
    #   "id": null,
    #   "result": {
    #     "jobs": [
    #       {
    #         "jobid": "56",
    #         "name": "RestoreFiles",
    #         "client": "client1--fd",
    #         "starttime": "2024-06-14 09:40:33",
    #         "duration": "00:00:28",
    #         "type": "R",
    #         "level": "F",
    #         "jobfiles": "59653",
    #         "jobbytes": "2504969851",
    #         "jobstatus": "T"
    #       }
    #     ]
    #   }
    # }
    local jobid_info
    jobid_info="$( bcommand_json "list jobid=$jobid" )"
    local job_jobstatus
    job_jobstatus="$( jq --exit-status --raw-output '.result.jobs[0].jobstatus' <<< "$jobid_info" )"

    # example output of 'bcommand_json ".jobstatus=E"':
    # {
    #   "jsonrpc": "2.0",
    #   "id": null,
    #   "result": {
    #     "jobstatus": [
    #       {
    #         "jobstatus": "E",
    #         "jobstatuslong": "Terminated with errors",
    #         "severity": "25",
    #         "exitlevel": "2",
    #         "exitstatus": "Error"
    #       }
    #     ]
    #   }
    # }
    # Note:
    #   exitstatus is
    #   "" when job is still running,
    #   "0" on OK,
    #   "1" OK with Warnings
    #   "2" Errors
    local jobstatus_info
    jobstatus_info="$( bcommand_json ".jobstatus=$job_jobstatus" )"
    jq --exit-status --raw-output '.result.jobstatus[0].exitlevel' <<< "$jobstatus_info"
}

#
# wait_restore_job():
#
#   return code:
#     0: OK
#     1: OK with warnings
#     >1: Error
#
#  Also sets RESTORE_JOBID to the jobid of the restore job.
#
function wait_restore_job()
{
    local last_restore_jobid_old="$1"
    unset RESTORE_JOBID

    ProgressStart "Waiting for Restore Job to start"
    local last_restore_jobid="${last_restore_jobid_old}"
    local wait_dots=""
    while [ "${last_restore_jobid}" = "${last_restore_jobid_old}" ]; do
        last_restore_jobid=$(get_last_restore_jobid)
        wait_dots+="."
        ProgressInfo "$wait_dots"
        sleep 1
    done
    ProgressStop

    RESTORE_JOBID=${last_restore_jobid}
    export RESTORE_JOBID
    Log "restore exists (${last_restore_jobid}) and differs from previous (${last_restore_jobid_old})."
    LogPrint "waiting for restore job ${last_restore_jobid} to finish."

    ProgressStart "Restoring data"
    local last_restore_exitstatus=""
    local used_disk_space
    local jobid_info
    while ! [ "$last_restore_exitstatus" ]; do
        # Example output: bcommand "list jobid=59"
        # Automatically selected Catalog: MyCatalog
        # Using Catalog "MyCatalog"
        # +-------+--------------+------------+---------------------+----------+------+-------+----------+----------+-----------+
        # | jobid | name         | client     | starttime           | duration | type | level | jobfiles | jobbytes | jobstatus |
        # +-------+--------------+------------+---------------------+----------+------+-------+----------+----------+-----------+
        # |    57 | RestoreFiles | client1-fd | 2024-06-14 10:13:48 | 00:00:21 | R    | F     |        0 |        0 | R         |
        # +-------+--------------+------------+---------------------+----------+------+-------+----------+----------+-----------+
        used_disk_space="$( total_target_fs_used_disk_space )"
        jobid_info="$( bcommand "list jobid=$last_restore_jobid" )"
        ProgressInfo "$( sed -n -r -e "s/  +/ /g" -e "s/^\| +(${last_restore_jobid} \|.*) +\|/| \1 | ${used_disk_space} |/p" <<< "$jobid_info" )"
        sleep "$PROGRESS_WAIT_SECONDS"
        last_restore_exitstatus="$( get_jobid_exitcode "${last_restore_jobid}" )"
    done
    ProgressStop

    LogPrint "$( bcommand "llist jobid=${last_restore_jobid}" )"
    LogPrint "Restored $(total_target_fs_used_disk_space)."

    return "${last_restore_exitstatus}"
}
