#
# prepare stuff for Galaxy 7
#

COPY_AS_IS+=( "${COPY_AS_IS_GALAXY7[@]}" )
COPY_AS_IS_EXCLUDE+=( "${COPY_AS_IS_EXCLUDE_GALAXY7[@]}" )

PROGS+=( chgrp touch )

# include argument file if specified
if test "$GALAXY7_Q_ARGUMENTFILE" ; then
	COPY_AS_IS+=( "$GALAXY7_Q_ARGUMENTFILE" )
fi
