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
