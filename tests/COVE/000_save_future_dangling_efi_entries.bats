setup_file() {
    export REAR_SHARE_DIR="$(realpath "$BATS_TEST_DIRNAME/../../usr/share/rear")"
    export USING_UEFI_BOOTLOADER="yes"
    export COVE_TESTS="yes"
}

setup() {
    function is_cove_in_azure() {
        false
    }

    # shellcheck disable=SC1091
    source "$REAR_SHARE_DIR/lib/global-functions.sh"
    
    # shellcheck disable=SC1091
    source "$REAR_SHARE_DIR/layout/recreate/COVE/default/130_save_future_dangling_efi_entries.sh"
}

teardown() {
    # Clean up any test-specific state if needed
    unset DISKS_TO_BE_OVERWRITTEN
}

@test "find single future dangling EFI entry" {
    function get_partuuids_of_disks_to_be_overwritten() {
        echo "368a5c5b-26bf-4a63-b9ae-64a92d79d085"
        echo "9bf08aed-f779-49fe-b310-9c21983289c1"
        echo "bc6f95e7-893a-434b-8b76-f3d52e6ad28d"
        echo "d96a0593-d527-424f-9174-b16f9e386dcb"
    }

    function get_efi_entries() {
        echo "BootCurrent: 0003"
        echo "BootOrder: 0003,0000,0001,0002"
        echo "Boot0000* EFI Virtual disk (0.0)	PcieRoot(0x8)/Pci(0x0,0x0)/SCSI(0,0)"
        echo "Boot0001* EFI VMware Virtual SATA CDROM Drive (0.0)	PcieRoot(0x8)/Pci(0x2,0x0)/Sata(0,0,0)"
        echo "Boot0002* EFI Network	PcieRoot(0x8)/Pci(0x1,0x0)/MAC(00505698f752,1)"
        # shellcheck disable=SC2028
        echo "Boot0003* Red Hat Enterprise Linux	HD(1,GPT,bc6f95e7-893a-434b-8b76-f3d52e6ad28d,0x800,0x12c000)/\\EFI\\redhat\\shimx64.efi"
        # shellcheck disable=SC2028
        echo "Boot0004* Red Hat Enterprise Linux	HD(1,GPT,bc6f95e7-0000-0000-0000-f3d52e6ad28d,0x800,0x12c000)/\\EFI\\redhat\\shimx64.efi"
    }

    local boot_number
    boot_number="$(get_future_dangling_efi_entries)"
    
    [ "$boot_number" = "0003" ]
}

@test "find multiple future dangling EFI entries" {
    function get_partuuids_of_disks_to_be_overwritten() {
        echo "bc6f95e7-893a-434b-8b76-f3d52e6ad28d"
    }

    function get_efi_entries() {
        # shellcheck disable=SC2028
        echo "Boot0003* Red Hat Enterprise Linux	HD(1,GPT,bc6f95e7-893a-434b-8b76-f3d52e6ad28d,0x800,0x12c000)/\\EFI\\redhat\\shimx64.efi"
        # shellcheck disable=SC2028
        echo "Boot0004* Red Hat Enterprise Linux	HD(1,MBR,bc6f95e7-893a-434b-8b76-f3d52e6ad28d,0x800,0x12c000)/\\EFI\\redhat\\grubx64.efi"
    }

    local boot_number
    boot_number="$(get_future_dangling_efi_entries)"
    
    [ "$boot_number" = "0003 0004" ]
}

@test "handle unexpected EFI entry format" {
    function get_partuuids_of_disks_to_be_overwritten() {
        echo "bc6f95e7-893a-434b-8b76-f3d52e6ad28d"
    }

    function get_efi_entries() {
        # shellcheck disable=SC2028
        echo "Bot0003 Red Hat Enterprise Linux	HD(1,GPT,bc6f95e7-893a-434b-8b76-f3d52e6ad28d,0x800,0x12c000)/\\EFI\\redhat\\shimx64.efi"
    }

    local boot_number
    boot_number="$(get_future_dangling_efi_entries)"
    
    [ -z "$boot_number" ]
}

@test "handle empty functions" {
    function get_partuuids_of_disks_to_be_overwritten() {
        :
    }

    function get_efi_entries() {
        :
    }

    local boot_number
    boot_number="$(get_future_dangling_efi_entries)"
    
    [ -z "$boot_number" ]
}

@test "handle get_partuuids_of_disks_to_be_overwritten error" {
    function get_partuuids_of_disks_to_be_overwritten() {
        return 1
    }

    function get_efi_entries() {
        :
    }

    run get_future_dangling_efi_entries
    [ "$status" -ne 0 ]
}

@test "get partuuids for one disk to be overwritten" {
    DISKS_TO_BE_OVERWRITTEN="/dev/sda"
    local expected_partuuids="368a5c5b-26bf-4a63-b9ae-64a92d79d085"

    function get_disk_partuuids() {
        local disk=$1

        if [ "$disk" != "/dev/sda" ]; then
            return 1
        fi

        echo "$expected_partuuids"
    }

    local actual_partuuids
    actual_partuuids="$(get_partuuids_of_disks_to_be_overwritten)"

    [ "$expected_partuuids" = "$actual_partuuids" ]
}

@test "get partuuids for two disks to be overwritten" {
    DISKS_TO_BE_OVERWRITTEN="/dev/sda /dev/sdb"

    function get_disk_partuuids() {
        local disk=$1

        if [ "$disk" = "/dev/sda" ]; then
            echo "9bf08aed-f779-49fe-b310-9c21983289c1"
        elif [ "$disk" = "/dev/sdb" ]; then
            echo "368a5c5b-26bf-4a63-b9ae-64a92d79d085"
        else
            return 1
        fi
    }

    local actual_partuuids
    actual_partuuids="$(get_partuuids_of_disks_to_be_overwritten)"

    local expected_partuuids="368a5c5b-26bf-4a63-b9ae-64a92d79d085"$'\n'"9bf08aed-f779-49fe-b310-9c21983289c1"

    [ "$expected_partuuids" = "$actual_partuuids" ]
}

@test "handle no disks to be overwritten" {
    DISKS_TO_BE_OVERWRITTEN=""

    function get_disk_partuuids() {
        :
    }

    local partuuids
    partuuids="$(get_partuuids_of_disks_to_be_overwritten)"

    [ -z "$partuuids" ]
}
