#
# prepare stuff for Commvault 11
#

COPY_AS_IS+=( "${COPY_AS_IS_GALAXY11[@]}" )
COPY_AS_IS_EXCLUDE+=( "${COPY_AS_IS_EXCLUDE_GALAXY11[@]}" )

REQUIRED_PROGS+=( chgrp touch )

# include argument file if specified
if test -s "$GALAXY11_Q_ARGUMENTFILE" ; then
	COPY_AS_IS+=( "$GALAXY11_Q_ARGUMENTFILE" )
else
	Error "GALAXY11_Q_ARGUMENTFILE is set but not readable or empty!"
fi
