# 300_parse_bp_conf.sh

# Parse /usr/openv/netbackup/bp.conf into NBU_* variables, such as
# NBU_SERVER and NBU_CLIENT_NAME, for later scripts to use. Runs after
# the operator pause in 250_check_nbu_client_name.sh, so this picks up
# whatever was last saved there, not whatever was on the recovery
# image at build time.

local nbu_bpconf=/usr/openv/netbackup/bp.conf
test -r "$nbu_bpconf" || Error "Cannot read $nbu_bpconf."

local line key value

# Split on the first '=', not on whitespace: bp.conf accepts "KEY = value",
# "KEY=value", and mixed spacing, but a plain 'read KEY VALUE' only splits
# on whitespace, so a no-space "SERVER=host" line lands entirely in $key
# and is never recognized as a SERVER line at all.
while IFS= read -r line ; do
    [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
    # Skip a directive with no '=' at all: both sed patterns below no-op
    # when there's no '=' to split on, which would otherwise set
    # NBU_<KEY> to its own key name as the value instead of being skipped.
    case "$line" in
        *=*) ;;
        *) continue ;;
    esac
    key=$( echo "$line" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*=.*//' )
    key="${key^^}"
    value=$( echo "$line" | sed -e 's/^[^=]*=[[:space:]]*//' -e 's/[[:space:]]*$//' )
    test -z "$key" && continue
    # Only these two keys are read downstream. The FIRST SERVER line is
    # the Primary server per NetBackup's convention, later ones are
    # Media servers and must not overwrite it.
    case "$key" in
        SERVER) test -n "$NBU_SERVER" && continue ;;
        CLIENT_NAME) ;;
        *) continue ;;
    esac
    export NBU_$key="$value"
done <"$nbu_bpconf"
