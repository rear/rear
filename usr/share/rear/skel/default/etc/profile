test "$PROFILEREAD" && return
PROFILEREAD=1


# Relax-and-Recover rescue system uses only /bin, all other default bin paths are symlinks
export PATH=/bin

spwd () {
  ( IFS=/
    set $PWD
    if test $# -le 3 ; then
	echo "$PWD"
    else
	eval echo \"..\${$(($#-1))}/\${$#}\"
    fi ) ; }
# Returns short path (last 18 characters)
ppwd () {
    local _w="$(dirs +0)"
    if test ${#_w} -le 18 ; then
	echo "$_w"
    else
	echo "...${_w:$((${#_w}-18))}"
    fi ; }
# If set: do not follow sym links
# set -P
#
# Other prompting for root
_t=""
if test "$UID" = 0 ; then
    _u="\h"
    _p=" #"
else
    _u="\u@\h"
    _p=">"
fi
PS1="RESCUE ${_t}${_u}:\w${_p} "
unset _u _p _t
alias dir='ls -l'
alias ll='ls -l'
alias la='ls -la'
alias l='ls -alF'
alias ls-l='ls -l'
alias md='mkdir -p'
alias which='type -p'
alias rehash='hash -r'
alias more='less'
export TERM=ansi

# print motd for interactive shells
tty -s && test -s /etc/motd && cat /etc/motd

true
