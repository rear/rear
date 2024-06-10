# Functions for manipulation of rsync URLs (both OUTPUT_URL and BACKUP_URL)

#### OLD STYLE:
# BACKUP_URL=[USER@]HOST:PATH           # using ssh (no rsh)
#
# with rsync protocol PATH is a MODULE name defined in remote /etc/rsyncd.conf file
# BACKUP_URL=[USER@]HOST::PATH          # using rsync
# BACKUP_URL=rsync://[USER@]HOST[:PORT]/PATH    # using rsync (is not compatible with new style!!!)

#### NEW STYLE:
# BACKUP_URL=rsync://[USER@]HOST[:PORT]/PATH    # using ssh
# BACKUP_URL=rsync://[USER@]HOST[:PORT]::/PATH  # using rsync

function rsync_validate () {
    local url="$1"

    if [[ "$(url_scheme "$url")" != "rsync" ]]; then # url_scheme still recognizes old style
        BugError "Non-rsync URL $url !"
    fi
}

# Determine whether the URL specifies the use of the rsync protocol (rsyncd) or ssh
# Do not call on non-rsync URLs (use url_scheme first)
function rsync_proto () {
    local url="$1"

    rsync_validate "$url"
    if grep -Eq '(::)' <<< $url ; then # new style '::' means rsync protocol
        echo rsync
    else
        echo ssh
    fi
}

# Functions to parse the URL into its components:
# USER, HOST, PORT, PATH

function rsync_user () {
    local url="$1"
    local host

    host="$(url_host "$url")"

    if grep -q '@' <<< $host ; then
        echo "${host%%@*}"    # grab user name
    else
        echo root
    fi
}

function rsync_host () {
    local url="$1"
    local host
    local path

    host="$(url_host "$url")"
    path="$(url_path "$url")"
    # remove USER@ if present
    local tmp2="${host#*@}"

    case "$(rsync_proto "$url")" in
        (rsync)
            # tmp2=witsbebelnx02::backup or tmp2=witsbebelnx02::
            echo "${tmp2%%::*}"
            ;;
        (ssh)
            # tmp2=host or tmp2=host:
            echo "${tmp2%%:*}"
            ;;
    esac
}

function rsync_path () {
    local url="$1"
    local host
    local path
    local url_without_scheme
    local url_without_scheme_user

    host="$(url_host "$url")"
    path="$(url_path "$url")"
    local tmp2="${host#*@}"

    url_without_scheme="${url#*//}"
    url_without_scheme_user="${url_without_scheme#$(rsync_user "$url")@}"

    case "$(rsync_proto "$url")" in

        (rsync)
            if grep -q '::' <<< $url_without_scheme_user ; then
                # we can not use url_path here, it uses / as separator, not ::
                local url_after_separator="${url_without_scheme_user##*::}"
                # remove leading / - this is a module name
                echo "${url_after_separator#/}"
            else
                echo "${path#*/}"
            fi
            ;;
        (ssh)
            if [ "$url_without_scheme" == "$url" ]; then
                # no scheme - old-style URL
                if grep -q ':' <<< $url_without_scheme_user ; then
                    echo "${url_without_scheme_user##*:}"
                else
                    BugError "Old-style rsync URL $url without : !"
                fi
            else
                echo "$path"
            fi
            ;;

    esac
}

function rsync_port () {
    # XXX changing port not implemented yet
    echo 873
}

# Full path to the destination directory on the remote server,
# includes RSYNC_PREFIX. RSYNC_PREFIX is not given by the URL,
# it is a global parameter (by default derived from hostname).
function rsync_path_full () {
    local url="$1"

    echo "$(rsync_path "$url")/${RSYNC_PREFIX}"
}

# Argument for the ssh command to log in to the remote host ("user@host")
function rsync_remote_ssh () {
    local url="$1"

    local user host

    user="$(rsync_user "$url")"
    host="$(rsync_host "$url")"

    echo "${user}@${host}"
}

# Argument for the rsync command to reach the remote host, without path.
function rsync_remote_base () {
    local url="$1"

    local user host port

    user="$(rsync_user "$url")"
    host="$(rsync_host "$url")"
    port="$(rsync_port "$url")"

    case "$(rsync_proto "$url")" in

        (rsync)
            echo "rsync://${user}@${host}:${port}/"
            ;;
        (ssh)
            echo "$(rsync_remote_ssh "$url"):"
            ;;

    esac
}

# Complete argument to rsync to reach the remote location identified by URL,
# but without the added RSYNC_PREFIX.
# This essentially converts our rsync:// URLs into a form accepted by the rsync command.
function rsync_remote () {
    local url="$1"

    echo "$(rsync_remote_base "$url")$(rsync_path "$url")"
}

# Complete argument to rsync including even RSYNC_PREFIX.
# Determined from the URL and RSYNC_PREFIX.
function rsync_remote_full () {
    local url="$1"

    echo "$(rsync_remote_base "$url")$(rsync_path_full "$url")"
}
