#
# prepare stuff for Commvault
#

COPY_AS_IS+=( "${COPY_AS_IS_COMMVAULT[@]}" )
COPY_AS_IS_EXCLUDE+=( "${COPY_AS_IS_EXCLUDE_COMMVAULT[@]}" )

PROGS+=( chgrp touch )

# include argument file if specified
if test "$COMMVAULT_Q_ARGUMENTFILE" ; then
	COPY_AS_IS+=( "$COMMVAULT_Q_ARGUMENTFILE" )
fi
