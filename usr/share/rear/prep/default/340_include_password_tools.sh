# Include tools to check TTY_ROOT_PASSWORD for terminal logins

# stderr is redirected here to avoid exposing the password hash in the log file when ReaR runs in debugscript mode.
{ [[ -n "$TTY_ROOT_PASSWORD" ]] && REQUIRED_PROGS+=( openssl ); } 2>/dev/null
