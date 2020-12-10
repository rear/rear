# Store TTY_ROOT_PASSWORD for terminal logins

[[ -n "$TTY_ROOT_PASSWORD" ]] && echo "$TTY_ROOT_PASSWORD" > "$ROOTFS_DIR/.TTY_ROOT_PASSWORD"
