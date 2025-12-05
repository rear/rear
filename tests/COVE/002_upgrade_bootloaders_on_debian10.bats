#
# Unit tests for upgrading Shim and GRUB bootloaders on Debian 10
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

    OS_VERSION=10
    USING_UEFI_BOOTLOADER=yes
    function is_cove_in_azure() {
        false
    }
    EFI_STUB=no
    UEFI_BOOTLOADER=/boot/efi/EFI/debian/shimx64.efi
}

@test "Shim and GRUB are upgraded successfully" {
    function upgrade_bootloaders() {
        return 0
    }

    run source "$REAR_SHARE_DIR/finalize/COVE/Debian/620_upgrade_bootloaders.sh"
    [ "$status" -eq 0 ]

    local expected_output="Upgraded signed Shim and GRUB bootloaders for this system."
    [ "$output" = "$expected_output" ]
}

@test "Failed to upgrade Shim and GRUB" {
    function upgrade_bootloaders() {
        return 1
    }

    run source "$REAR_SHARE_DIR/finalize/COVE/Debian/620_upgrade_bootloaders.sh"
    [ "$status" -eq 0 ]

    local expected_output="Failed to upgrade signed Shim and GRUB bootloaders for this system. UEFI Secure Boot might not be available."
    [ "$output" = "$expected_output" ]
}

@test "Skip upgrading Shim and GRUB if the system is not Debian 10" {
    # shellcheck disable=SC2034
    OS_VERSION=11

    run source "$REAR_SHARE_DIR/finalize/COVE/Debian/620_upgrade_bootloaders.sh"
    [ "$status" -eq 0 ]

    local expected_output=""
    [ "$output" = "$expected_output" ]
}

@test "Skip upgrading Shim and GRUB if the system is not EFI" {
    # shellcheck disable=SC2034
    USING_UEFI_BOOTLOADER=no

    run source "$REAR_SHARE_DIR/finalize/COVE/Debian/620_upgrade_bootloaders.sh"
    [ "$status" -eq 0 ]

    local expected_output=""
    [ "$output" = "$expected_output" ]
}

@test "Skip upgrading Shim and GRUB on Azure" {
    function is_cove_in_azure() {
        true
    }

    run source "$REAR_SHARE_DIR/finalize/COVE/Debian/620_upgrade_bootloaders.sh"
    [ "$status" -eq 0 ]

    local expected_output=""
    [ "$output" = "$expected_output" ]
}

@test "Skip upgrading Shim and GRUB if the system is EFI stub" {
    # shellcheck disable=SC2034
    EFI_STUB=yes

    run source "$REAR_SHARE_DIR/finalize/COVE/Debian/620_upgrade_bootloaders.sh"
    [ "$status" -eq 0 ]

    local expected_output=""
    [ "$output" = "$expected_output" ]
}

@test "Skip upgrading Shim and GRUB if the bootloader is not shim" {
    # shellcheck disable=SC2034
    UEFI_BOOTLOADER=/boot/efi/EFI/debian/grubx64.efi

    run source "$REAR_SHARE_DIR/finalize/COVE/Debian/620_upgrade_bootloaders.sh"
    [ "$status" -eq 0 ]

    local expected_output=""
    [ "$output" = "$expected_output" ]
}
