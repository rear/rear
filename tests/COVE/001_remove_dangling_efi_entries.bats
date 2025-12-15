#!/bin/env bats

setup_file() {
    export REAR_SHARE_DIR="$(realpath "$BATS_TEST_DIRNAME/../../usr/share/rear")"
    export USING_UEFI_BOOTLOADER="yes"
    export COVE_TESTS="yes"
}

setup() {
    function is_cove_in_azure() {
        false
    }

    function LogPrint() {
        echo "$@"
    }

    # shellcheck disable=SC1091
    source "$REAR_SHARE_DIR/lib/global-functions.sh"

    # shellcheck disable=SC1091
    source "$REAR_SHARE_DIR/finalize/COVE/default/665_remove_dangling_efi_entries.sh"
}

@test "no future dangling efi entries" {
    FUTURE_DANGLING_EFI_ENTRIES=""
    
    run remove_dangling_efi_entries

    [ "$status" -eq 0 ]
}

@test "one entry to remove" {
    FUTURE_DANGLING_EFI_ENTRIES="0001"

    function remove_efi_entry() {
        :
    }

    local expected_output="Removing EFI Boot Manager entry with '0001' entry ID"

    run remove_dangling_efi_entries

    [ "$status" -eq 0 ]
    [ "$output" = "$expected_output" ]
}

@test "two entries to remove" {
    FUTURE_DANGLING_EFI_ENTRIES="0001 0003"

    function remove_efi_entry() {
        :
    }

    local expected_output
    expected_output="$(printf "%s\n%s" \
        "Removing EFI Boot Manager entry with '0001' entry ID" \
        "Removing EFI Boot Manager entry with '0003' entry ID")"

    run remove_dangling_efi_entries

    [ "$status" -eq 0 ]
    [ "$output" = "$expected_output" ]
}

@test "fail to remove efi entry" {
    FUTURE_DANGLING_EFI_ENTRIES="0001 0003"

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

    run remove_dangling_efi_entries

    [ "$status" -eq 0 ]
    [ "$output" = "$expected_output" ]
}
