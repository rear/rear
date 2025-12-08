#!/usr/bin/env bash

SCRIPT_DIR="$(dirname "${0}")"
SCRIPT_DIR="$(realpath "${SCRIPT_DIR}")"
readonly SCRIPT_DIR

REAR_SHARE_DIR=$(realpath "$SCRIPT_DIR/../../usr/share/rear")
readonly REAR_SHARE_DIR

# shellcheck disable=SC1091
source "$REAR_SHARE_DIR/lib/global-functions.sh"

# shellcheck disable=SC2034
readonly USING_UEFI_BOOTLOADER="yes"

# shellcheck disable=SC2034
readonly COVE_TESTS="yes"

function is_cove_in_azure() {
    false
}

function no_future_dangling_efi_entries() {
    FUTURE_DANGLING_EFI_ENTRIES=""
    remove_dangling_efi_entries
}

function one_entry_to_remove() {
    FUTURE_DANGLING_EFI_ENTRIES="0001"

    function LogPrint() {
        echo "$@"
    }

    function remove_efi_entry() {
        :
    }

    local expected_output="Removing EFI Boot Manager entry with '0001' entry ID"

    local actual_output
    actual_output="$(remove_dangling_efi_entries)"

    [ "$expected_output" = "$actual_output" ]
}

function two_entries_to_remove() {
    # shellcheck disable=SC2034
    FUTURE_DANGLING_EFI_ENTRIES="0001 0003"

    function LogPrint() {
        echo "$@"
    }

    function remove_efi_entry() {
        :
    }

    local expected_output
    expected_output="$(printf "%s\n%s" \
        "Removing EFI Boot Manager entry with '0001' entry ID" \
        "Removing EFI Boot Manager entry with '0003' entry ID")"

    local actual_output
    actual_output="$(remove_dangling_efi_entries)"

    [ "$expected_output" = "$actual_output" ]
}

function fail_to_remove_efi_entry() {
    # shellcheck disable=SC2034
    FUTURE_DANGLING_EFI_ENTRIES="0001 0003"

    function LogPrint() {
        echo "$@"
    }

    function remove_efi_entry() {
        local id="$1"
        if [ "$id" = "0001" ]; then
            return 0
        elif [ "$id" = "0003" ]; then
            return 1
        fi
    }

    local expected_output
    expected_output="$(printf "%s\n%s\n%s" \
        "Removing EFI Boot Manager entry with '0001' entry ID" \
        "Removing EFI Boot Manager entry with '0003' entry ID" \
        "Failed to remove EFI Boot Manager entry with '0003' entry ID"
    )"

    local actual_output
    actual_output="$(remove_dangling_efi_entries)"

    [ "$expected_output" = "$actual_output" ]
}

set -e

TESTS=(
    no_future_dangling_efi_entries
    one_entry_to_remove
    two_entries_to_remove
    fail_to_remove_efi_entry
)

for test in "${TESTS[@]}"; do
    # shellcheck disable=SC1091
    source "$REAR_SHARE_DIR/finalize/COVE/default/665_remove_dangling_efi_entries.sh"
    if ! "$test"; then
        echo "$test failed"
        exit 1
    fi
done
