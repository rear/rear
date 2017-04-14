# 400_check_extlinux.sh
if ! has_binary extlinux; then
    Error "Executable extlinux is missing! Please install syslinux-extlinux or alike"
fi
