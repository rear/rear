# 400_check_extlinux.sh

is_true $SYSTEMD_BOOT && return

if ! has_binary extlinux; then
    Error "Executable extlinux is missing! Please install syslinux-extlinux or alike"
fi
