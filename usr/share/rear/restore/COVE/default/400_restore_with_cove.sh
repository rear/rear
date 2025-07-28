#
# Restore files and folders with Cove
#

# ANSI color escape sequences
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m' # No color

readonly COVE_CLIENT_TOOL="${COVE_INSTALL_DIR}/bin/ClientTool"

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
    "${COVE_CLIENT_TOOL}" control.status.get
}

# Shows progress of running session (%, ETA)
function cove_show_progress() {
    "${COVE_CLIENT_TOOL}" show.progress-bar 1>&7 2>&8
}

# Returns ProcessController's process id
function get_pc_pid() {
    ps aux | awk -v pc_name=${PC_NAME} '$0 ~ pc_name && !/awk/ {print $2}'
}

# Stops ProcessController process
function cove_stop_pc() {
    local pid="$(get_pc_pid)"
    [ -z "$pid" ] || { /bin/kill -TERM "${pid}" && \
    while [ -n "$pid" ]; do \
        sleep 1; \
        pid="$(get_pc_pid)"; \
    done }
}

# Print the welcome message
UserOutput "
The System is now ready for restore."

# Read parameters from boot options. The existing values can be overridden
# by values passed via boot options.
read -r cmdline </proc/cmdline
for option in $cmdline; do
    case $option in
        cove_timestamp=*)
            COVE_TIMESTAMP="${option#cove_timestamp=}"
            ;;
    esac
done

# Move Backup manager installation files to target file system
mkdir -p "$(dirname "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}")"
mv "${COVE_INSTALL_DIR}" "$(dirname "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}")"
ln -s "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}" "${COVE_INSTALL_DIR}"

# Start Backup Manager
"${COVE_INSTALL_DIR}/bin/ProcessController" serve

# Wait for the Backup Manager to enter the idle state
cove_print "Waiting for the Backup Manager to enter the idle state... "
cove_wait_for 'local status="$(cove_get_status)"; [ "${status}" = "Idle" ]' 2 && \
    cove_print_done || { cove_print_error; Error "The Backup Manager couldn't enter the idle state."; }

# Initiate the restore Files and folders
restore_args=(
    control.restore.start
    -datasource FileSystem
    -restore-to "${TARGET_FS_ROOT}"
    -exclude "${COVE_REAL_INSTALL_DIR}"
    -session-search-policy OldestIfRequestedNotFound
)
[ -z "${COVE_TIMESTAMP}" ] || restore_args+=( -time "${COVE_TIMESTAMP}" )

"${COVE_CLIENT_TOOL}" "${restore_args[@]}"
StopIfError "Failed to start the restore."

# Wait for the restore to be started
cove_print "Waiting for the restore to be started... "
cove_wait_for 'local status="$(cove_get_status)"; [ "${status}" = "Scanning" -o "${status}" = "Restore" ]' 2 \
    && cove_print_done || { cove_print_error; Error "The restore has not started."; }

# Show progress bar for restore session
cove_show_progress || Error "Restore failed."

# Stop ProcessController process
cove_stop_pc

# Create symlink for the Backup Manager install dir if it's necessary
if [ "${COVE_INSTALL_DIR}" != "${COVE_REAL_INSTALL_DIR}" -a ! -h "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}" ]; then
    mkdir -p "$(dirname "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}")"
    ln -s "${COVE_REAL_INSTALL_DIR}" "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}"
fi
