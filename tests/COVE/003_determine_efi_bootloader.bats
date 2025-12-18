#!/usr/bin/env bats

#
# Unit tests for determining EFI bootloaders
#

function setup_file() {
    REAR_SHARE_DIR="$(realpath "$BATS_TEST_DIRNAME/../../usr/share/rear")"
    export REAR_SHARE_DIR
}

function setup() {
    # shellcheck disable=SC1091
    source "$REAR_SHARE_DIR/lib/global-functions.sh"

    function LogPrint() {
        echo "$@"
    }
}

function source_efi_functions {
    # shellcheck disable=SC1091
    source "$REAR_SHARE_DIR/lib/uefi-functions.sh"
}

@test "Get current boot entry" {
    function efi_run_efibootmgr {
        echo "BootCurrent: 0001"
        echo "BootOrder: 0003,0000,0001,0002"
        echo "Boot0000* EFI Virtual disk (0.0)	PcieRoot(0x8)/Pci(0x0,0x0)/SCSI(0,0)"
        echo "Boot0001* EFI VMware Virtual SATA CDROM Drive (0.0)	PcieRoot(0x8)/Pci(0x2,0x0)/Sata(0,0,0)"
        echo "Boot0002* EFI Network	PcieRoot(0x8)/Pci(0x1,0x0)/MAC(00505698f752,1)"
    }

    source_efi_functions

    local current_boot
    current_boot=$(efi_get_current_boot)

    [ "$current_boot" = "0001" ]
}

@test "Get EFI device path" {
    function efi_run_efibootmgr {
        echo "BootCurrent: 0003"
        echo "BootOrder: 0003,0000,0001,0002"
        echo "Boot0000* EFI Virtual disk (0.0)	PcieRoot(0x8)/Pci(0x0,0x0)/SCSI(0,0)"
        echo "Boot0001* EFI VMware Virtual SATA CDROM Drive (0.0)	PcieRoot(0x8)/Pci(0x2,0x0)/Sata(0,0,0)"
        echo "Boot0002* EFI Network	PcieRoot(0x8)/Pci(0x1,0x0)/MAC(00505698f752,1)"
        # shellcheck disable=SC2028
        echo "Boot0003* Red Hat Enterprise Linux	HD(1,GPT,bc6f95e7-893a-434b-8b76-f3d52e6ad28d,0x800,0x12c000)/\\EFI\\redhat\\shimx64.efi"
        # shellcheck disable=SC2028
        echo "Boot0004* My GRUB	HD(1,GPT,bc6f95e7-893a-434b-8b76-f3d52e6ad28d,0x800,0x12c000)/\\EFI\\redhat\\grubx64.efi"
    }

    source_efi_functions

    local dp
    dp=$(efi_get_device_path "0003")
    [ "$dp" = "HD(1,GPT,bc6f95e7-893a-434b-8b76-f3d52e6ad28d,0x800,0x12c000)/\EFI\redhat\shimx64.efi" ]

    dp=$(efi_get_device_path "0004")
    [ "$dp" = "HD(1,GPT,bc6f95e7-893a-434b-8b76-f3d52e6ad28d,0x800,0x12c000)/\EFI\redhat\grubx64.efi" ]
}

@test "Failed get EFI device path" {
    function efi_run_efibootmgr {
        return 1
    }

    source_efi_functions

    run efi_get_device_path "0003"

    [ $status -eq 1 ]
    [ -z "$output" ]

    function efi_run_efibootmgr {
        echo "Boot0000* EFI Virtual disk (0.0)	PcieRoot(0x8)/Pci(0x0,0x0)/SCSI(0,0)"
    }

    run efi_get_device_path "0001"

    [ $status -eq 1 ]
    [ -z "$output" ]
}

@test "Get bootloader path" {
    local num="0003"
    function efi_get_device_path {
        if [ "$1" != "$num" ]; then
            return 1
        fi
        # shellcheck disable=SC2028
        echo "HD(1,GPT,bc6f95e7-893a-434b-8b76-f3d52e6ad28d,0x800,0x12c000)/\\EFI\\redhat\\grubx64.efi"
    }

    source_efi_functions

    local bootloader_path
    bootloader_path=$(efi_get_bootloader_path "$num")

    [ "$bootloader_path" = "/EFI/redhat/grubx64.efi" ]
}

@test "Failed to get bootloader path" {
    function efi_get_device_path {
        return 1
    }

    source_efi_functions

    run efi_get_bootloader_path "0003"

    [ $status -eq 1 ]
    [ -z "$output" ]

    function efi_get_device_path {
        echo "HD(1,GPT,bc6f95e7-893a-434b-8b76-f3d52e6ad28d,0x800,0x12c000)"
    }

    [ $status -eq 1 ]
    [ -z "$output" ]
}

@test "Get EFI boot partuuid for GPT" {
    local num="0003"
    function efi_get_device_path {
        if [ "$1" != "$num" ]; then
            return 1
        fi
        # shellcheck disable=SC2028
        echo "HD(1,GPT,bc6f95e7-893a-434b-8b76-f3d52e6ad28d,0x800,0x12c000)/\\EFI\\redhat\\grubx64.efi"
    }

    source_efi_functions

    local partuuid
    partuuid=$(efi_get_boot_partuuid "$num")

    [ "$partuuid" = "bc6f95e7-893a-434b-8b76-f3d52e6ad28d" ]
}

@test "Get current full EFI bootloader path" {
    function efi_run_efibootmgr {
        echo "BootCurrent: 0003"
        echo "BootOrder: 0003,0000,0001,0002"
        echo "Boot0000* EFI Virtual disk (0.0)	PcieRoot(0x8)/Pci(0x0,0x0)/SCSI(0,0)"
        echo "Boot0001* EFI VMware Virtual SATA CDROM Drive (0.0)	PcieRoot(0x8)/Pci(0x2,0x0)/Sata(0,0,0)"
        echo "Boot0002* EFI Network	PcieRoot(0x8)/Pci(0x1,0x0)/MAC(00505698f752,1)"
        # shellcheck disable=SC2028
        echo "Boot0003* Red Hat Enterprise Linux	HD(1,GPT,bc6f95e7-893a-434b-8b76-f3d52e6ad28d,0x800,0x12c000)/\\EFI\\redhat\\shimx64.efi"
    }

    function efi_get_mountpoint {
        if [ "$1" != "bc6f95e7-893a-434b-8b76-f3d52e6ad28d" ]; then
            return 1
        fi

        echo "/boot/efi"
    }

    function efi_check_bootloader_path {
        return 0
    }

    source_efi_functions

    local full_path
    full_path="$(efi_get_current_full_bootloader_path)"

    [ "$full_path" = "/boot/efi/EFI/redhat/shimx64.efi" ]
}

@test "Failed to get current full EFI bootloader path: cannot get current boot" {
    function efi_get_current_boot {
        return 1
    }

    source_efi_functions

    run efi_get_current_full_bootloader_path

    [ $status -eq 1 ]
    [ "$output" = "WARN: EFI: Failed to get current boot" ]
}

@test "Failed to get current full EFI bootloader path: cannot get partuuid" {
    function efi_get_current_boot {
        echo "0000"
    }

    function efi_get_boot_partuuid {
        return 1
    }

    source_efi_functions

    run efi_get_current_full_bootloader_path

    [ $status -eq 1 ]
    [ "$output" = "WARN: EFI: Failed to get partuuid for the current boot '0000'" ]
}

@test "Failed to get current full EFI bootloader path: cannot get mountpoint" {
    function efi_get_current_boot {
        echo "0000"
    }

    local uuid="bc6f95e7-893a-434b-8b76-f3d52e6ad28d"
    function efi_get_boot_partuuid {
        echo "$uuid"
    }

    function efi_get_mountpoint {
        return 1
    }

    source_efi_functions

    run efi_get_current_full_bootloader_path

    [ $status -eq 1 ]
    [ "$output" = "WARN: EFI: Failed to get mountpoint for partuuid '$uuid'" ]
}

@test "Failed to get current full EFI bootloader path: cannot get bootloader path" {
    function efi_get_current_boot {
        echo "0000"
    }

    local uuid="bc6f95e7-893a-434b-8b76-f3d52e6ad28d"
    function efi_get_boot_partuuid {
        echo "$uuid"
    }

    function efi_get_mountpoint {
        echo "/boot/efi"
    }

    function efi_get_bootloader_path {
        return 1
    }

    source_efi_functions

    run efi_get_current_full_bootloader_path

    [ $status -eq 1 ]
    [ "$output" = "WARN: EFI: Failed to get bootloader path for the current boot '0000'" ]
}

@test "Failed to get current full EFI bootloader path: bootloader path does not exist" {
    function efi_get_current_boot {
        echo "0000"
    }

    local uuid="bc6f95e7-893a-434b-8b76-f3d52e6ad28d"
    function efi_get_boot_partuuid {
        echo "$uuid"
    }

    function efi_get_mountpoint {
        echo "/boot/efi"
    }

    function efi_get_bootloader_path {
        echo "/EFI/redhat/shimx64.efi"
    }

    function efi_check_bootloader_path {
        return 1
    }

    source_efi_functions

    run efi_get_current_full_bootloader_path

    [ $status -eq 1 ]
    [ "$output" = "WARN: EFI: Bootloader path '/boot/efi/EFI/redhat/shimx64.efi' does not exist" ]
}
