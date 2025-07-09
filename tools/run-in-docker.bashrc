PATH=/rear/tools:$PATH:/rear/usr/sbin

alias egrep='grep -E --color=auto'
alias grep='grep --color=auto'
alias l='ls -CF'
alias la='ls -A'
alias ll='ls -alF'
alias ls='ls --color=auto'

_t=""
if test "$UID" = 0; then
    _u="\h"
    _p=" #"
else
    _u="\u@\h"
    _p=">"
fi
PS1="DOCKER ${_t}${_u}:\w${_p} "
unset _u _p _t

find-package() {
    local package_names=("$@")
    local results=()
    if command -v apt-get &>/dev/null; then
        for package in "${package_names[@]}"; do
            results+=($(apt-cache -q search --names-only "$package" | awk '{print $1}'))
        done
    elif command -v zypper &>/dev/null; then
        results+=($(zypper --quiet --terse search "${package_names[@]}" | awk '/^i |^v |^ |^  / {print $2}'))
    elif command -v yum &>/dev/null; then
        for package in "${package_names[@]}"; do
            # old yum output:
            # groff-base.x86_64 : Parts of the groff formatting system required to display manual pages
            # new yum output:
            #  groff-base.x86_64: Parts of the groff formatting system required to display manual pages
            # this handles both:
            results+=($(yum search "$package" 2>/dev/null | awk -F '[ :]+' '/ : / {print $1}; /^ / {print $2}'))
        done
    elif command -v pacman &>/dev/null; then
        for package in "${package_names[@]}"; do
            results+=($(pacman -Ss "$package" | awk -F'[/ ]' '/^community|^extra|^core|^multilib/ {print $2}'))
        done
    else
        echo "No supported package manager found" >&2
        return 1
    fi
    if [[ ${#results[@]} -gt 0 ]]; then
        printf "%s\n" "${results[@]}" | sort -u
    fi
}
