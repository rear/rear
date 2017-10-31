# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# At SLES11 /usr/bin/python is a link to ./python2.6
# and because copy failed with an error "cp: not writing through dangling symlink"
# we need to put in the link target ...

PYTHON="$(which python)"

if [ -h "$PYTHON" ]; then
    PYTHON_BIN=$(basename $(readlink "$PYTHON"))
else
    PYTHON_BIN="python"
fi

REQUIRED_PROGS=( "${REQUIRED_PROGS[@]}" gpg duplicity "$PYTHON_BIN" )

# duply is a really good shell script wrapper for duplicity
PROGS=( "${PROGS[@]}" duply )

COPY_AS_IS=(
"${COPY_AS_IS[@]}"
/etc/duply
/etc/python
/etc/python2.6
/etc/python2.7
/root/.duply
/root/.duplicity
/root/.gnupg
/usr/lib/pymodules
/usr/lib/pyshared
/usr/lib/python2.6
/usr/lib64/python2.6
/usr/lib64/python2.6/lib-dynload
/usr/lib64/python2.6/site-packages
/usr/lib64/python2.6/site-packages/gnupg.py
/usr/lib64/python2.6/site-packages/GnuPGInterface.py
/usr/lib64/python2.6/site-packages/duplicity
/usr/lib/python2.7
/usr/lib64/python2.7
/usr/lib/python3
/usr/lib/python3.1
/usr/share/pycentral-data
/usr/share/pyshared
/usr/share/pyshared-data
/usr/share/python
/usr/share/python-apt
/usr/share/python-support
/var/lib/pycentral
/usr/include/python2.6/pyconfig-64.h
/usr/include/python2.7/pyconfig.h
)

LIBS=(
"${LIBS[@]}"
/usr/lib/librsync.so.1.0.2
/usr/lib64/librsync.so.1
/usr/lib/x86_64-linux-gnu/librsync.so.1
/usr/lib64/libexpat.so.1
/lib/libexpat.so.1
/lib/x86_64-linux-gnu/libexpat.so.1
/usr/lib/cruft
)

# hard code the BACKUP_PROG to duplicity
BACKUP_PROG=duplicity
