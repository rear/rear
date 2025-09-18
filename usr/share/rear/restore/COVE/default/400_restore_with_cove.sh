#
# Restore files and folders with Cove
#

# ANSI color escape sequences
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m' # No color

readonly COVE_CLIENT_TOOL="${COVE_INSTALL_DIR}/bin/ClientTool"

SKIP_PROGRESS_BAR=0

# Waits until a condition succeeds
# $1: condition command
# $2: interval between checks
function cove_wait_for() {
    local condition="$1"
    local interval="$2"
    while true; do
        if eval "${condition}"; then
            break
        fi
        sleep "${interval}"
    done
}

# Prints a message without appending a newline
# $@: message to print
function cove_print() {
    { printf "$*" 1>&7 || true ; } 2>>"/dev/$DISPENSABLE_OUTPUT_DEV"
}

# Prints "Done!" message
function cove_print_done() {
    cove_print "${GREEN}Done!${NC}\n"
}

# Prints "Error!" message
function cove_print_error() {
    cove_print "${RED}Error!${NC}\n"
}

# Gets the BackupFP status
function cove_get_status() {
    "${COVE_CLIENT_TOOL}" control.status.get 2>/dev/null
}

# Shows progress of running session (%, ETA)
function cove_show_progress() {
    [ "${SKIP_PROGRESS_BAR}" -eq 1 ] && return 0

    "${COVE_CLIENT_TOOL}" show.progress-bar 1>&7 2>&8 &
    local pid=$!

    # Remap interruption hotkey from Ctrl-c to Ctrl-]
    stty intr ^]

    while kill -0 "$pid" 2>/dev/null; do
        if read -r -t 0.1 -n 1 key && [ "$key" == $'\x03' ]; then
            kill -9 "$pid" 2>/dev/null
            break
        fi
    done

    # Remap interruption hotkey back to Ctrl-c
    stty intr ^C

    wait "$pid"
    return $?
}

# Returns ProcessController's process id
function get_pc_pid() {
    local pc_name="ProcessController"
    ps aux | awk -v pc_name=${pc_name} '$0 ~ pc_name && !/awk/ {print $2}'
}

# Stops ProcessController process
function cove_stop_pc() {
    local pid
    pid="$(get_pc_pid)"
    [ -z "$pid" ] || { /bin/kill -TERM "${pid}" && \
    while [ -n "$pid" ]; do \
        sleep 1; \
        pid="$(get_pc_pid)"; \
    done }
}

# Starts ProcessController process
function cove_start_pc() {
    local pid
    pid="$(get_pc_pid)"
    if [ -z "$pid" ]; then
        "${COVE_INSTALL_DIR}/bin/ProcessController" serve
    fi
}

# Gets FileSystem restore sessions
function cove_get_filesystem_restore_sessions() {
    "${COVE_CLIENT_TOOL}" control.session.list -no-header 2>/dev/null \
        | awk '$1 == "FileSystem" && $2 == "Restore"'
}

# Waits for a new FileSystem restore session and gets its status
# $1: prev sessions
function cove_wait_for_new_session() {
    local sessions_prev="$1"
    local status=""
    for _ in {1..90}; do
        local sessions_cur
        sessions_cur="$(cove_get_filesystem_restore_sessions)"
        local new_session
        new_session=$(printf "$sessions_prev\n$sessions_cur" | sort | uniq -u)
        if [ -n "$new_session" ]; then
            status=$(echo "$new_session" | awk 'NF > 2 {print $3; exit}')
            break
        fi
        sleep 2
    done
    echo "$status"
}

# Print the welcome message
UserOutput "
The System is now ready for restore."

# Move Backup manager installation files to target file system
mkdir -p "$(dirname "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}")"
mv "${COVE_INSTALL_DIR}" "$(dirname "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}")"
ln -s "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}" "${COVE_INSTALL_DIR}"

# Start Backup Manager
cove_start_pc

# Wait for the Backup Manager to enter the Idle state
cove_print "Waiting for the Backup Manager to enter the Idle state... "
cove_wait_for 'local status="$(cove_get_status)"; [ "${status}" = "Idle" ]' 2 && \
    cove_print_done || { cove_print_error; Error "The Backup Manager couldn't enter the Idle state."; }

# Initiate the restore Files and folders
restore_args=(
    control.restore.start
    -datasource FileSystem
    -restore-to "${TARGET_FS_ROOT}"
    -exclude "${COVE_REAL_INSTALL_DIR}"
    -session-search-policy OldestIfRequestedNotFound
)
[ -z "${COVE_TIMESTAMP}" ] || restore_args+=( -time "${COVE_TIMESTAMP}" )

prompt="Select what to do"
rear_workflow="rear $WORKFLOW"

unset choices
choices[0]="Try starting the restore again"
choices[1]="Use Relax-and-Recover shell and return back to here"
choices[2]="Abort '$rear_workflow'"
choice=""

while true; do
    # Save FileSystem restore sessions before starting a new restore session
    # in order to find it and check its status
    sessions_prev="$(cove_get_filesystem_restore_sessions)"

    if "${COVE_CLIENT_TOOL}" "${restore_args[@]}"; then
        # Wait for the restore to be started
        cove_print "Waiting for the restore to be started... "

        status="$(cove_wait_for_new_session "$sessions_prev")"
        if [ -z "$status" ]; then
            cove_print_error
            LogPrintError "The restore has not started: timeout expired."
        else
            cove_print_done
            case "$status" in
                InProcess)
                    break
                    ;;
                Completed)
                    SKIP_PROGRESS_BAR=1
                    break
                    ;;
                *)
                    LogPrintError "The restore failed: session status '${status}'."
                    ;;
            esac
        fi

    else
        LogPrintError "Failed to start the restore."
    fi

    LogPrint ""
    while true; do
        choice="$(UserInput -I COVE_START_RESTORE_CHOICE -p "$prompt" -D "${choices[0]}" "${choices[@]}")"
        case "$choice" in
            ("${choices[0]}")
                break
                ;;
            ("${choices[1]}")
                LogPrint ""
                LogPrint "Failing to start the restore might be due to unavailable FileSystem"
                LogPrint "backup sessions or the Backup Manager being in a Suspended state."
                LogPrint "The following commands might be useful for troubleshooting:"
                LogPrint "$COVE_CLIENT_TOOL control.status.get"
                LogPrint "$COVE_CLIENT_TOOL control.session.list"
                LogPrint ""
                LogPrint "Type 'exit' to leave the shell and return to the recovery process."
                LogPrint ""
                rear_shell ""
                ;;
            ("${choices[2]}")
                Error "Failed to start the restore."
                ;;
        esac
    done
done

# Show progress bar for restore session

unset choices
choices[0]="Use Relax-and-Recover shell for troubleshooting and then return back to recovery"
choices[1]="Abort '$rear_workflow'"
choice=""

cove_show_progress
rc=$?

if [ $rc -ne 0 ]; then
    LogPrint ""
    if [ $rc -ne 137 ]; then
        available_disk_space=$(df -hP "$TARGET_FS_ROOT" | tail -1 | awk '{print $4}')
        LogPrint "Restore failed."
        LogPrint "Info: Restore may fail due to insufficient available disk space. Available disk space: $available_disk_space."
    else
        LogPrint "Progress bar has been killed, however, the restore session might be still in progress."
    fi
    LogPrint ""

    while true; do
        choice="$(UserInput -I COVE_FINISH_RESTORE_CHOICE -p "$prompt" -D "${choices[1]}" "${choices[@]}")"
        case "$choice" in
            ("${choices[0]}")
                LogPrint ""
                LogPrint "The following commands might be useful for troubleshooting:"
                LogPrint "$COVE_CLIENT_TOOL control.status.get"
                LogPrint "$COVE_CLIENT_TOOL control.session.list"
                LogPrint ""
                LogPrint "Type '$COVE_CLIENT_TOOL show.progress-bar' if a restore session is still in progress."
                LogPrint "Type 'exit' to leave the shell and return to the recovery process."
                LogPrint ""
                rear_shell "Has the restore been completed, and are you ready to continue the recovery? (y/n)"
                break
                ;;
            ("${choices[1]}")
                "${COVE_CLIENT_TOOL}" control.session.abort || true
                Error "Restore failed."
                ;;
        esac
    done
fi

# Stop ProcessController process
cove_stop_pc

# Create symlink for the Backup Manager install dir if it's necessary
if [ "${COVE_INSTALL_DIR}" != "${COVE_REAL_INSTALL_DIR}" -a ! -h "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}" ]; then
    mkdir -p "$(dirname "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}")"
    ln -s "${COVE_REAL_INSTALL_DIR}" "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}"
fi
