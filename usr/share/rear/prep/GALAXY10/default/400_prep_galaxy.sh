#
# prepare stuff for Galaxy 10
#

COPY_AS_IS+=( "${COPY_AS_IS_GALAXY10[@]}" )
COPY_AS_IS_EXCLUDE+=( "${COPY_AS_IS_EXCLUDE_GALAXY10[@]}" )

PROGS+=( chgrp touch )

# include argument file if specified
if test "$GALAXY10_Q_ARGUMENTFILE" ; then
	COPY_AS_IS+=( "$GALAXY10_Q_ARGUMENTFILE" )
fi
