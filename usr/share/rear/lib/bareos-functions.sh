#
# Bareos helper functions.
#

#
# helper functions for easier handling bconsole output
# (remove irrelevant parts of the output).
#
function bcommand()
{
    local OPTIND=1
    local pre_commands=( "." )
    while getopts ":p:" option "$@"; do
        case $option in
            (p)
                pre_commands+=( "$OPTARG" )
                ;;
            (\?)
                BugError "Invalid option: -$OPTARG"
                ;;
        esac
    done
    shift $((OPTIND-1))
    local command="$1"

    local output
    output=$(
        (
            for i in "${pre_commands[@]}"; do
                echo "$i"
            done
            echo "$command"
        ) | bconsole
    )
    local rc=$?
    (( rc > 0 )) && return $rc

    local command_as_regex
    command_as_regex=$( sed -e 's/\./\\./g' -e 's/\//\\\//g' <<< "$command" )

    # Remove all header lines, by searching when the provided command appears in the output.
    # In api mode json, a "}" may appear at the start of the line.
    sed -r "0,/^[}]?${command_as_regex}$/d" <<< "$output"
}

function bcommand_json()
{
  bcommand -p ".api json compact=no" "$1"
  return $?
}

function bcommand_extract_value()
{
  local key="$1"
  local sed_arg
  sed_arg="$(printf 's/^ *%s: (.*) *$/\\1/p' "$key")"
  sed -n -r "${sed_arg}"
}

function bareos_ensure_client_is_available()
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
    # With bcommand the strip information normally not relevant ("Connecting to the Bareos Director", ...).
    # To get all status information we use the plain bconsole command here.
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
    jq --exit-status --raw-output '[ .result.jobs[].jobid ] | max' <<< "$bcommand_result"
}

function get_jobstatus_exitcode()
{
    local jobstatus="$1"

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
    jobstatus_info="$( bcommand_json ".jobstatus=$jobstatus" )"
    jq --exit-status --raw-output '.result.jobstatus[0].exitlevel' <<< "$jobstatus_info"
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

    get_jobstatus_exitcode "$job_jobstatus"
}


function wait_for_newer_restore_job_to_start()
{
    local last_restore_jobid_old="$1"

    ProgressStart "Waiting for Restore Job to start"
    local last_restore_jobid="$last_restore_jobid_old"
    declare -i count=60
    while [ "$last_restore_jobid" = "$last_restore_jobid_old" ]; do
        last_restore_jobid=$( get_last_restore_jobid )
        (( count-- ))
        ProgressInfo "Waiting for Restore Job to start (${count}s) "
        if (( count <= 0 )); then
            # Restore Job did not start!
            return 1
        fi
        sleep 1
    done
    ProgressStop

    echo "$last_restore_jobid"
}


#
# wait_restore_job():
#
#   return code:
#     0: OK
#     1: OK with warnings
#     >1: Error
#
function wait_restore_job()
{
    local restore_jobid="$1"

    [ "$restore_jobid" ] || Error "No restore jobid given"

    LogPrint "Information about restore job $restore_jobid:"
    LogPrint "$( bcommand "llist jobid=$restore_jobid" )"
    LogPrint "Waiting for restore job $restore_jobid to finish."

    ProgressStart "Restoring data"
    local restore_exitstatus=""
    local used_disk_space
    local jobid_info
    local starttime
    local duration
    local jobstatus
    # empty string means no status yet
    while ! [ "$restore_exitstatus" ]; do
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
        used_disk_space="$( total_target_fs_used_disk_space )"
        jobid_info="$( bcommand_json "list jobid=$restore_jobid" )"
        starttime="$( jq -r '.result.jobs[0].starttime' <<< "$jobid_info" )"
        duration="$( jq -r '.result.jobs[0].duration' <<< "$jobid_info" )"
        jobstatus="$( jq -r '.result.jobs[0].jobstatus' <<< "$jobid_info" )"
        restore_exitstatus="$( get_jobstatus_exitcode "$jobstatus" )"
        ProgressInfo "Start: [$starttime], Duration: [$duration], Status: [$jobstatus], Restored: [$used_disk_space] "
        sleep "$PROGRESS_WAIT_SECONDS"
    done
    ProgressStop

    LogPrint "Information about finished job:"
    LogPrint "$( bcommand "llist jobid=$restore_jobid" )"
    LogPrint "Restored $(total_target_fs_used_disk_space)"

    return "$restore_exitstatus"
}
