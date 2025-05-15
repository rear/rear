#
# Restore files and folders with Cove
#

# ANSI color escape sequences
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly NC='\033[0m' # No color

readonly COVE_CLIENT_TOOL="${COVE_INSTALL_DIR}/bin/ClientTool"
readonly COVE_TMPDIR="${TARGET_FS_ROOT}/covetmp-$(date +"%y%m%d%H%M%S")"

COVE_INSTALLER_PATH="${COVE_TMPDIR}/mxb-linux-x86_64.run"
COVE_INSTALLATION_TOKEN=""

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

# Prompts the user with yes/no question and handles default responses
# $1: Prompt message to display
# $2: Default value (y or n) if the user just presses Enter
function cove_ask() {
    local message="$1"
    local default_value="$2"
    local value=""
    while true; do
        read -r -p "${message} (y/n) [${default_value}]: " value 0<&6 1>&7 2>&8
        value="${value:-$default_value}"
        case "$value" in
            [yY][eE][sS]|[yY])
                return 0
                ;;
            [nN][oO]|[nN])
                return 1
                ;;
            *)
                 UserOutput "Invalid input. Please answer y/n."
                ;;
        esac
    done
}

# Gets the BackupFP status
function cove_get_status() {
    "${COVE_CLIENT_TOOL}" control.status.get
}

# Shows progress of running session (%, ETA)
function cove_show_progress() {
    "${COVE_CLIENT_TOOL}" show.progress-bar 1>&7 2>&8
}

# Downloads the Backup Manager installer
function cove_download_bm_installer() {
    if [ -z "${COVE_INSTALLER_URL}" ]; then
        UserOutput ""
        UserOutput "Please provide the URL to download the Backup Manager installer:"
        read -r -p "URL: " COVE_INSTALLER_URL 0<&6 1>&7 2>&8
    fi

    UserOutput ""
    cove_print "Downloading Backup Manager installer... "
    if command -v curl >/dev/null 2>&1 ; then
        curl -fsSL "${COVE_INSTALLER_URL}" -o "${COVE_INSTALLER_PATH}" \
            && cove_print_done || { cove_print_error; return 1; }
    else
        wget -q "${COVE_INSTALLER_URL}" -O "${COVE_INSTALLER_PATH}" \
            && cove_print_done || { cove_print_error; return 1; }
    fi
}

# Creates a symbolic link to a specified target directory
# If the link already exists and points to the correct target, nothing is done.
# If a conflicting file or directory exists at the link location, it is removed.
# Ensures that both the link's parent directory and the target directory exist.
# $1: Target directory the symlink should point to
# $2: Path to the symbolic link to create
function cove_create_symlink() {
    local target="$1"
    local link_name="$2"

    # The necessary link already exists and is correct
    [ -h "${link_name}" ] && [ "$(readlink -f "${link_name}")" = "${target}" ] && return 0

    # Remove existing file or directory at link location
    [ ! -e "${link_name}" ] || { \
        PrintError "'${link_name}' already exists. It will be removed."; rm -rf "${link_name}"; }

    # Create parent directories for the symlink if needed
    mkdir -p "$(dirname "${link_name}")"

    # Ensure the target directory exists
    mkdir -p "${target}"

    # Create the symbolic link
    ln -s "${target}" "${link_name}" || { \
        PrintError "Failed to create '${link_name}' symlink to '${target}' target"; return 1; }
}

# Attempts to mount an OverlayFS over a given lower directory
# This is used to redirect the Backup Manager installation to a disk.
# $1: Lower directory (read-only base layer)
# $2: Upper directory (writable layer)
function cove_try_overlayfs() {
    # Exit if OverlayFS redirection is disabled
    [ "${COVE_TRY_OVERLAYFS}" = "1" ] || return 1

    # Exit if OverlayFS has already been successfully applied
    [ "${COVE_OVERLAYFS_SUCCESS}" != "1" ] || return 0

    local lower="$1"
    local upper="$2"

    # Create the lower directory if it doesn't exist
    # If we create it, mark it for removal on failure (since it'll be a symlink)
    local rm_lower=0
    [ -e "${lower}" ] || { mkdir -p "${lower}" && rm_lower=1; }

    # Ensure the upper directory exists
    mkdir -p "${upper}"

    # Prepare the work directory required by OverlayFS
    local work="${COVE_TMPDIR}/work"
    mkdir -p "${work}"

    # Attempt to mount the overlay
    mount -t overlay overlay -o \
        lowerdir="${lower}",upperdir="${upper}",workdir="${work}" \
        "${lower}" || { rm -rf "${work}"; [ "${rm_lower}" = "0" ] || rm -rf "${lower}"; return 1; }

    # Mark OverlayFS as successfully applied
    readonly COVE_OVERLAYFS_SUCCESS=1
}

# Attempts to unmount an OverlayFS-mounted directory
# $1: Merged directory
function cove_umount_overlayfs() {
    local merged="$1"
    # Try to unmount 10 times
    for i in {1..10}; do
        [ "$i" -eq 1 ] || sleep 3
        umount "${merged}" && return 0 || continue
    done
    return 1
}

# Installs the Backup Manager
# The installation is redirected to a disk via OverlayFS if it's enabled, or via symlinks otherwise.
function cove_install_bm() {
    if [ -z "${COVE_INSTALLATION_TOKEN}" ]; then
        UserOutput ""
        UserOutput "Please provide the installation token:"
        read -r -p "Token: " COVE_INSTALLATION_TOKEN 0<&6 1>&7 2>&8
    fi

    local new_installer="cove#v1#${COVE_INSTALLATION_TOKEN}#.run"
    local new_installer_path="$(dirname "${COVE_INSTALLER_PATH}")/${new_installer}"

    # Rename the Backup Manager installer
    mv "${COVE_INSTALLER_PATH}" "${new_installer_path}"
    COVE_INSTALLER_PATH="${new_installer_path}"

    [ -x "${COVE_INSTALLER_PATH}" ] || chmod +x "${COVE_INSTALLER_PATH}"

    local target_install_dir="${TARGET_FS_ROOT}/${COVE_REAL_INSTALL_DIR#/}"

    # First, try OverlayFS to redirect the installation to a disk
    if ! cove_try_overlayfs "${COVE_INSTALL_DIR}" "${target_install_dir}"; then
        # Create symlinks to redirect the installation to a disk
        if [ "${COVE_INSTALL_DIR}" != "${COVE_REAL_INSTALL_DIR}" ]; then
            local target="${target_install_dir}"
            local link_name="${COVE_INSTALL_DIR}"
            cove_create_symlink "${target}" "${link_name}" || return $?
        else
            cove_dirs=(bin etc lib sbin share temp var/log var/storage)
            for cove_dir in "${cove_dirs[@]}"; do
                local target="${target_install_dir}/${cove_dir}"
                local link_name="${COVE_INSTALL_DIR}/${cove_dir}"
                cove_create_symlink "${target}" "${link_name}" || return $?
            done
        fi
    fi

    UserOutput ""
    UserOutput "Installing Backup Manager..."
    "${COVE_INSTALLER_PATH}" --target "${COVE_TMPDIR}/mxb" 1>&7 2>&8 || return $?

    # Extract the ReaR tarball because the installer does not do it in the rescue environment
    mkdir -p "${target_install_dir}/rear"
    tar -xf "${COVE_TMPDIR}/mxb/rear.tar.gz" --strip-components=1 -C "${target_install_dir}/rear"

    # Try to copy site.conf if it does not exist at the target.
    # It happens in case of symlinks used to redirect the installation.
    [ -e "${target_install_dir}/rear/etc/rear/site.conf" ] \
        || cp "${COVE_INSTALL_DIR}/rear/etc/rear/site.conf" "${target_install_dir}/rear/etc/rear/site.conf" \
        || true
}

# Stops ProcessController process
function cove_stop_pc() {
    local pid="$(ps aux | awk -v pc_name=ProcessController '$0 ~ pc_name && !/awk/ {print $2}')"
    [ -z "$pid" ] || { /bin/kill -TERM "${pid}" && \
    while [ -n "$pid" ]; do \
        sleep 1; \
        pid="$(get_pc_pid)"; \
    done }
}

# Print the welcome message
UserOutput "
The System is now ready for restore. The Backup Manager installer will be
downloaded and run automatically. If any required parameters have not been
provided, you will be prompted to enter them."

# Read parameters from boot options. The existing values can be overridden
# by values passed via boot options.
read -r cmdline </proc/cmdline
for option in $cmdline; do
    case $option in
        cove_installer=*)
            COVE_INSTALLER_URL="${option#cove_installer=}"
            ;;
        cove_token=*)
            COVE_INSTALLATION_TOKEN="${option#cove_token=}"
            ;;
        cove_timestamp=*)
            COVE_TIMESTAMP="${option#cove_timestamp=}"
            ;;
    esac
done

mkdir -p "${COVE_TMPDIR}"

# Download the Backup Manager installer
while true; do
    if cove_download_bm_installer; then
        break
    else
        PrintError "Failed to download the Backup Manager installer."
        if cove_ask "Want to try again?" "y"; then
            cove_ask "Want to change the Backup Manager installer URL?" "y" && \
                COVE_INSTALLER_URL="" || true
            continue
        else
            Error "Failed to download the Backup Manager installer."
        fi
    fi
done

# Install the Backup manager installer
while true; do
    if cove_install_bm; then
        break
    else
        PrintError "Failed to install Backup Manager"
        if cove_ask "Want to try again?" "y"; then
            cove_ask "Want to change the installation token?" "y" && \
                COVE_INSTALLATION_TOKEN="" || true
            continue
        else
            Error "Failed to install Backup Manager."
        fi
    fi
done

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

# Unmount OverlayFS
if [ "${COVE_OVERLAYFS_SUCCESS}" = "1" ]; then
    cove_print "Unmounting '${COVE_INSTALL_DIR}'... "
    cove_umount_overlayfs "${COVE_INSTALL_DIR}" && cove_print_done || { cove_print_error; \
        PrintError "Failed to unmount '${COVE_INSTALL_DIR}'. The Backup Manager might be broken on the recovered machine." ; }
fi

# Create symlink for the Backup Manager install dir if it's necessary
if [ "${COVE_INSTALL_DIR}" != "${COVE_REAL_INSTALL_DIR}" -a ! -h "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}" ]; then
    mkdir -p "$(dirname "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}")"
    ln -s "${COVE_REAL_INSTALL_DIR}" "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}"
fi

# Clean up
rm -rf "${COVE_TMPDIR}"
