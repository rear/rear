#!/bin/bash
ME="$(type -p "$0" || readlink -f "$0")"

p="$(type -p pidof)"

if ! test "$p" ; then
	echo "ERROR: pidof is not installed on your system:"
	lsb_release -a || echo "ERROR: lsb_release not found!"
	exit 1
fi

# do not run if another instance is running. pidof -x will always report at least $$
if [ $$ != "$("$p" -x "$ME")" ] ; then
        echo "$ME is already running, not starting again"
        exit 0
else
	echo "Starting instance of $ME (sleeping 10sec)"
	if package=$(dpkg -S "$p" 2>/dev/null) ; then
		package="${package%%:*}"
	elif package=$(rpm -qf "$p" 2>/dev/null) ; then
		: noop
	else
		package="unknown packaging source"
	fi
	echo "pidof is '$p' and comes from '$package'"
	lsb_release -a 2>/dev/null || echo "ERROR: lsb_release not found!"
	# finish sleeping till this program ran 10 seconds
	while let "SECONDS<10" ; do sleep 1 ; done
fi


