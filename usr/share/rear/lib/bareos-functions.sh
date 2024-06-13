#
# helper functions for easier handling bconsole output
# (remove irrelevant parts of the output).
#

function bcommand()
{
  local out=$(mktemp)
  local precommand="@output $out\n"
  if [ "$PRECOMMAND" ]; then
    precommand="${PRECOMMAND}\n${precommand}"
  fi
  (printf "$precommand"; for i in "$@"; do echo "$i"; done) | bconsole > /tmp/bconsole.$!
  rc=$?

  # remove submitted commands from output.
  local sed_args="(You have messages."
  for i in "$@"; do
    sed_args+="|$i"
  done
  sed_args+=")"

  sed -r -e "/^${sed_args}$/d" -e "s/${sed_args}$//" < $out
  rm $out
  return $rc
}

function bcommand_json()
{
  PRECOMMAND=".api json compact=no" bcommand "$@"
  return $?
}

function bcommand_extract_value()
{
  local key="$1"
  local sed_arg="$(printf 's/^ *%s: (.*) *$/\\1/p' "$key")"
  sed -n -r "${sed_arg}"
}

function bcommand_json_extract_value()
{
  local key="$1"
  local sed_arg="$(printf 's/^ *"%s": "(.*)".*$/\1/p' "$key")"
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

    local bconsole_client_status=$(bconsole <<< "status client=$client")
    local rc=$?
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
{(
    set -e
    set -o pipefail
    
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
    bcommand_json "show jobs" | jq --raw-output '.result.jobs | with_entries(select(.value.type == "Restore")) | .[].name'
)}
