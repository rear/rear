# cove-functions.sh
#
# Cove DP specific functions
#

# Print text in a framed box
function cove_print_in_frame() {
    local title="$1"
    local text="$2"

    title=$(echo -e "$title")
    text=$(echo -e "$text")

    local term_width
    term_width=$(tput cols)
    local min_term_width=40
    local max_box_width=120

    (( term_width < min_term_width )) && { text=$(echo -e "$title\n$text"); LogUserOutput "$text"; return; }
    (( term_width > max_box_width )) && term_width=$max_box_width

    local box_width=$((term_width - 4))

    if has_binary fold ; then
        text=$(fold -s -w "$box_width" <<< "$text")
        local max_len
        max_len=$(awk '{ if (length > max) max = length } END { print max }' <<< "$text")
        max_len=$((max_len + 4))

        local title_len
        title_len=$(echo -n "$title" | wc -c)
        local left_space=$(( (max_len - title_len) / 2 ))
        title="$(printf "%*s%s\n" "$left_space" "" "$title")"

        text=$(echo -e "$title\n$text")

        if has_binary boxes ; then
            text=$(boxes -d stone -i text -s "$max_len" <<< "$text")
        fi
    else
        text=$(echo -e "$title\n$text")
    fi

    LogUserOutput "$text"
}

function is_cove() {
    [ "$BACKUP" = "COVE" ]
}

# Since there is no reliable way of detecting whether it is running in a container or not,
# it only tries to guess.
function is_container() {
    # Podman
    # /run/.containerenv is automatically created within the container.
    # However, it is not created when a volume is mounted on /run
    if [ -f /run/.containerenv ] || grep -qa container=podman /proc/1/environ ; then
        echo "Podman"
        return 0
    fi

    # Linux Containers
    if grep -qa container=lxc /proc/1/environ ; then
        echo "LXC"
        return 0
    fi

    # Docker
    if [ -f /.dockerenv ]; then
        echo "Docker"
        return 0
    fi

    # Kubernetes
    if grep -qa KUBERNETES_SERVICE_HOST /proc/1/environ ; then
        echo "Kubernetes"
        return 0
    fi

    return 1
}

function cove_error_if_container() {
    is_cove || return 1

    local container
    container=$(is_container) || return 1

    Error "The system is detected as ${container} container. System state is not supported for containers."
}
