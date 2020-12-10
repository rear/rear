# Include tools to check TTY_ROOT_PASSWORD for terminal logins
[[ -n "$TTY_ROOT_PASSWORD" ]] && REQUIRED_PROGS+=( openssl )
