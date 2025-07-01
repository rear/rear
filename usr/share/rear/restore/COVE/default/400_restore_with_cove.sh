#
# Restore files and folders with Cove
#

readonly COVE_CLIENT_TOOL="${COVE_INSTALL_DIR}/bin/ClientTool"

COVE_INSTALLATION_TOKEN=""

# Waits until a condition succeeds
# $1: condition command
# $2: interval between checks
function cove_wait_for() {
    local condition="$1"
    local interval="$2"
    while true; do
        if eval "$condition"; then
            break
        fi
        sleep "$interval"
    done
}

# Gets the BackupFP status
function cove_get_status() {
    "$COVE_CLIENT_TOOL" control.status.get
}

# Downloads the Backup Manager installer
function cove_download_bm_installer() {
    if [ -z "$COVE_INSTALLER_URL" ]; then
        UserOutput ""
        local prompt="Please enter the URL to download the Backup Manager installer:"
        COVE_INSTALLER_URL="$(UserInput -I COVE_INSTALLER_URL -r -t 0 -p "$prompt")"
    fi

    UserOutput ""
    ProgressStart "Downloading Backup Manager installer... "
    if has_binary curl ; then
        curl -fsSL "$COVE_INSTALLER_URL" -o "$COVE_INSTALLER_PATH" \
            && ProgressStop || { ProgressError; return 1; }
    else
        wget -q "$COVE_INSTALLER_URL" -O "$COVE_INSTALLER_PATH" \
            && ProgressStop|| { ProgressError; return 1; }
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
    [ -h "$link_name" ] && [ "$(readlink -f "$link_name")" = "$target" ] && return 0

    # Remove existing file or directory at link location
    if [ -e "$link_name" ]; then
        LogPrintError "'$link_name' already exists. It will be removed."
        rm -rf "$link_name"
    fi

    # Create parent directories for the symlink if needed
    mkdir -p "$(dirname "$link_name")"

    # Ensure the target directory exists
    mkdir -p "$target"

    # Create the symbolic link
    if ! ln -s "$target" "$link_name"; then
        LogPrintError "Failed to create '$link_name' symlink to '$target' target."
        return 1
    fi
}

# Attempts to mount an OverlayFS over a given lower directory
# This is used to redirect the Backup Manager installation to a disk.
# $1: Lower directory (read-only base layer)
# $2: Upper directory (writable layer)
function cove_try_overlayfs() {
    # Exit if OverlayFS redirection is disabled
    is_true "$COVE_TRY_OVERLAYFS" || return 1

    # Exit if OverlayFS has already been successfully applied
    ! is_true "$COVE_OVERLAYFS_SUCCESS" || return 0

    local lower="$1"
    local upper="$2"

    # Create the lower directory if it doesn't exist
    # If we create it, mark it for removal on failure (since it'll be a symlink)
    local rm_lower=0
    [ -e "$lower" ] || { mkdir -p "$lower" && rm_lower=1; }

    # Ensure the upper directory exists
    mkdir -p "$upper"

    # Prepare the work directory required by OverlayFS
    local work="${COVE_TMPDIR}/work"
    mkdir -p "$work"

    # Attempt to mount the overlay
    if ! mount -t overlay overlay -o lowerdir="$lower",upperdir="$upper",workdir="$work" "$lower"; then
        LogPrintError "Failed to create OverlayFS to redirect the Backup Manager installation to the target disk."
        rm -rf "$work"
        is_true "$rm_lower" && rm -rf "$lower"
        return 1
    fi
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
        umount "$merged" && return 0 || continue
    done
    return 1
}

# Installs the Backup Manager
# The installation is redirected to a disk via OverlayFS if it's enabled, or via symlinks otherwise.
function cove_install_bm() {
    if [ ! -e "$COVE_INSTALLER_PATH" ]; then
        LogPrintError "The Backup Manager installer does not exist at '$COVE_INSTALLER_PATH'."
        return 1
    fi

    if [ -z "$COVE_INSTALLATION_TOKEN" ]; then
        UserOutput ""
        local prompt="Please enter the installation token:"
        { COVE_INSTALLATION_TOKEN="$(UserInput -I COVE_INSTALLATION_TOKEN -C -r -t 0 -p "$prompt")" ; } 2>>/dev/$SECRET_OUTPUT_DEV
    fi

    {
        local new_installer_path="${COVE_TMPDIR}/cove#v1#${COVE_INSTALLATION_TOKEN}#.run"
        if [ "$COVE_INSTALLER_PATH" != "$new_installer_path" ]; then
            # Rename the Backup Manager installer to enable Unified Installation Flow
            mv "$COVE_INSTALLER_PATH" "$new_installer_path"
            COVE_INSTALLER_PATH="$new_installer_path"
        fi

        [ -x "$COVE_INSTALLER_PATH" ] || chmod +x "$COVE_INSTALLER_PATH"
    } 2>>/dev/$SECRET_OUTPUT_DEV

    local target_install_dir="${TARGET_FS_ROOT}/${COVE_REAL_INSTALL_DIR#/}"

    # First, try OverlayFS to redirect the installation to a disk
    if ! cove_try_overlayfs "$COVE_INSTALL_DIR" "$target_install_dir"; then
        # Create symlinks to redirect the installation to a disk
        if [ "$COVE_INSTALL_DIR" != "$COVE_REAL_INSTALL_DIR" ]; then
            local target="$target_install_dir"
            local link_name="$COVE_INSTALL_DIR"
            cove_create_symlink "${target}" "${link_name}" || return $?
        else
            cove_dirs=(bin etc lib sbin share temp var/log var/storage)
            for cove_dir in "${cove_dirs[@]}"; do
                local target="${target_install_dir}/${cove_dir}"
                local link_name="${COVE_INSTALL_DIR}/${cove_dir}"
                cove_create_symlink "$target" "$link_name" || return $?
            done
        fi
    fi

    UserOutput ""
    UserOutput "Installing Backup Manager..."
    "$COVE_INSTALLER_PATH" --target "${COVE_TMPDIR}/mxb" 1>&7 2>&8 || return $?

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
    local pid
    pid="$(ps aux | awk -v pc_name=ProcessController '$0 ~ pc_name && !/awk/ {print $2}')"
    [ -z "$pid" ] || { /bin/kill -TERM "$pid" && \
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
        (cove_installer=*)
            COVE_INSTALLER_URL="${option#cove_installer=}"
            ;;
        (cove_token=*)
            COVE_INSTALLATION_TOKEN="${option#cove_token=}"
            ;;
        (cove_timestamp=*)
            COVE_TIMESTAMP="${option#cove_timestamp=}"
            ;;
    esac
done

COVE_TMPDIR="$(mktemp -d "${TARGET_FS_ROOT}/cove.XXXXXXXXXX")"
readonly COVE_TMPDIR

COVE_INSTALLER_PATH="${COVE_TMPDIR}/mxb-linux-x86_64.run"

prompt="Select what to do"
rear_workflow="rear $WORKFLOW"

unset choices
choices[0]="Try downloading the Backup Manager installer again"
choices[1]="Change the Backup Manager installer URL"
choices[2]="Use Relax-and-Recover shell and return back to here"
choices[3]="Abort '$rear_workflow'"
choice=""

while true; do
    cove_download_bm_installer && break || \
        LogPrintError "Failed to download the Backup Manager installer from '${COVE_INSTALLER_URL}'."

    while true; do
        choice="$(UserInput -I COVE_DOWNLOAD_CHOICE -p "$prompt" -D "${choices[0]}" "${choices[@]}")"
        case "$choice" in
            ("${choices[0]}")
                break
                ;;
            ("${choices[1]}")
                COVE_INSTALLER_URL=""
                break
                ;;
            ("${choices[2]}")
                rear_shell ""
                ;;
            ("${choices[3]}")
                Error "Download aborted. User declined to retry after the Backup Manager download failed."
                ;;
        esac
    done
done

choices[0]="Try installing the Backup Manager again"
choices[1]="Change the installation token"
choice=""

while true; do
    cove_install_bm && break || LogPrintError "Failed to install the Backup Manager."

    while true; do
        choice="$(UserInput -I COVE_INSTALLATION_CHOICE -p "$prompt" -D "${choices[0]}" "${choices[@]}")"
        case "$choice" in
            ("${choices[0]}")
                break
                ;;
            ("${choices[1]}")
                COVE_INSTALLATION_TOKEN=""
                break
                ;;
            ("${choices[2]}")
                rear_shell ""
                ;;
            ("${choices[3]}")
                Error "Installation aborted. User declined to retry after the Backup Manager installation failed."
                ;;
        esac
    done
done

# Wait for the Backup Manager to enter the idle state
ProgressStart "Waiting for the Backup Manager to enter the idle state... "
if cove_wait_for 'local status="$(cove_get_status)"; [ "${status}" = "Idle" ]' 2; then
    ProgressStop
else
    ProgressError
    Error "The Backup Manager couldn't enter the idle state."
fi

# Initiate the restore Files and folders
restore_args=(
    control.restore.start
    -datasource FileSystem
    -restore-to "$TARGET_FS_ROOT"
    -exclude "$COVE_REAL_INSTALL_DIR"
    -session-search-policy OldestIfRequestedNotFound
)
[ -z "$COVE_TIMESTAMP" ] || restore_args+=( -time "$COVE_TIMESTAMP" )

unset choices
choices[0]="Try starting the restore again"
choices[1]="Use Relax-and-Recover shell and return back to here"
choices[2]="Abort '$rear_workflow'"
choice=""

while true; do
    "$COVE_CLIENT_TOOL" "${restore_args[@]}" && break || LogPrintError "Failed to start the restore."

    while true; do
        choice="$(UserInput -I COVE_RESTORE_CHOICE -p "$prompt" -D "${choices[0]}" "${choices[@]}")"
        case "$choice" in
            ("${choices[0]}")
                break
                ;;
            ("${choices[1]}")
                rear_shell ""
                ;;
            ("${choices[2]}")
                Error "Failed to start the restore."
                ;;
        esac
    done
done

# Wait for the restore to be started
ProgressStart "Waiting for the restore to be started... "
if cove_wait_for 'local status="$(cove_get_status)"; [ "${status}" = "Scanning" -o "${status}" = "Restore" ]' 2; then
    ProgressStop
else
    ProgressError
    Error "The restore has not started."
fi

# Wait for the restore to be finished
ProgressStart "Waiting for the restore to be finished... "
if cove_wait_for 'local status="$(cove_get_status)"; [ "${status}" = "Idle" ]' 15; then
    ProgressStop
else
    ProgressError
    Error "The restore has not finished."
fi

# Stop ProcessController process
cove_stop_pc

# Unmount OverlayFS
if is_true "$COVE_OVERLAYFS_SUCCESS"; then
    ProgressStart "Unmounting '${COVE_INSTALL_DIR}'... "
    if cove_umount_overlayfs "$COVE_INSTALL_DIR"; then
        ProgressStop
    else
        ProgressError
        LogPrintError "Failed to unmount '${COVE_INSTALL_DIR}'. The Backup Manager might be broken on the recovered machine."
    fi
fi

# Create symlink for the Backup Manager install dir if it's necessary
if [ "$COVE_INSTALL_DIR" != "$COVE_REAL_INSTALL_DIR" ] && [ ! -h "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}" ]; then
    mkdir -p "$(dirname "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}")"
    ln -s "${COVE_REAL_INSTALL_DIR}" "${TARGET_FS_ROOT}/${COVE_INSTALL_DIR#/}"
fi

# Clean up
rm -rf "$COVE_TMPDIR"
