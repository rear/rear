# udev-workflow.sh
#
# udev workflow for Relax-and-Recover
#
#    Relax-and-Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax-and-Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax-and-Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

if [[ "$VERBOSE" ]]; then
    WORKFLOW_udev_DESCRIPTION="udev handler; triggered by udev rule"
fi
WORKFLOWS=( ${WORKFLOWS[@]} udev )
WORKFLOW_udev () {
    # If no udev workflow has been defined, exit cleanly
    if [[ -z "$UDEV_WORKFLOW" ]]; then
        Log "Variable UDEV_WORKFLOW not set, skipping udev workflow."
        return
    fi

    WORKFLOW="$UDEV_WORKFLOW"

    # Triggered by block-device, so force OUTPUT
    OUTPUT=USB

    # Set USB_DEVICE based on ID_FS_LABEL or UDEV DEVNAME
    if [[ "$ID_FS_LABEL" && -b "/dev/disk/by-label/$ID_FS_LABEL" ]]; then
        Log "Using USB device based on udev ID_FS_LABEL '$ID_FS_LABEL'"
        USB_DEVICE="/dev/disk/by-label/$ID_FS_LABEL"
    elif [[ "$DEVNAME" && -b "$DEVNAME" ]]; then
        Log "Using USB device based on udev DEVNAME '$DEVNAME'"
        USB_DEVICE="$DEVNAME"
    else
        Log "We cannot determine USB device from udev, using configuration"
    fi

    # If udev workflow does not exist, bail out loudly
    has_binary WORKFLOW_$WORKFLOW
    StopIfError "Udev workflow '$UDEV_WORKFLOW' does not exist"

    # Turn the UID led on
    if has_binary hpasmcli && [[ "$UDEV_UID_LED" =~ ^[yY1] ]]; then
        hpasmcli -s "set uid on" >&8
    fi

    # Run udev workflow
    WORKFLOW_$UDEV_WORKFLOW "${ARGS[@]}"

    # Blink the UID led and turn it off
    if has_binary hpasmcli && [[ "$UDEV_UID_LED" =~ ^[yY1] ]]; then
        hpasmcli -s "set uid off" >&8; sleep 0.5
        hpasmcli -s "set uid on" >&8; sleep 0.5
        hpasmcli -s "set uid off" >&8; sleep 0.5
        hpasmcli -s "set uid on" >&8; sleep 0.5
        hpasmcli -s "set uid off" >&8
    fi

    # Suspend USB port (works fine on RHEL6, fails on RHEL5 and older)
    if [[ "$DEVPATH" && "$UDEV_SUSPEND" =~ ^[yY1] ]]; then
        path="/sys$DEVPATH"
        Log "Trying to suspend USB device at '$path'"
        while [[ "$path" != "/sys" && ! -w "$path/power/level" ]]; do
            path=$(dirname $path)
        done
        if [[ -w "$path/power/level" ]]; then
            Log "Suspending USB device at '$path'"
            echo -n suspend >$path/power/level
        fi
    fi

    # Beep distinctively
    if [[ "$UDEV_BEEP" =~ ^[yY1] ]]; then
        ### Make sure we have a PC speaker driver loaded
        if grep -q pcpskr /proc/modules || modprobe pcspkr; then
            Log "Beep through PC speaker."
            if has_binary beep; then
                # After testing in a noisy datacenter, this seems the best
                # (although it takes up 4 seconds)
                beep -f 2000 -l 1000 -d 500 -r 3 >&8
            else
                for i in $(seq 1 15); do
                    echo -en "\a" >/dev/tty0
                    sleep 0.05
                done
            fi
        else
            LogPrint "Speaker driver failed to load, no beeps, sorry !"
        fi
    fi
}
