PATH=/rear/tools:$PATH:/rear/usr/sbin

alias egrep='egrep --color=auto'
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
