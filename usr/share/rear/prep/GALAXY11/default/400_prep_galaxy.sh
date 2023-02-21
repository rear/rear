#
# prepare stuff for Commvault 11
#

COPY_AS_IS+=("${COPY_AS_IS_GALAXY11[@]}")
COPY_AS_IS_EXCLUDE+=("${COPY_AS_IS_EXCLUDE_GALAXY11[@]}")

# I don't actually know what for we need this, was introduced in GALAXY7 (Schlomo)
REQUIRED_PROGS+=(chgrp touch)

# we need at least 1500MB free disk space
USE_RAMDISK=1500

# include argument file if specified
if test "$GALAXY11_Q_ARGUMENTFILE"; then
	if test -s "$GALAXY11_Q_ARGUMENTFILE"; then
		COPY_AS_IS+=("$GALAXY11_Q_ARGUMENTFILE")
	else
		Error "GALAXY11_Q_ARGUMENTFILE is set but not readable or empty!"
	fi
fi
