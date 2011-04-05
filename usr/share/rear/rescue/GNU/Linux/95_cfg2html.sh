# we support using cfg2html to collect general system information. For this cfg2html has to
# be installed and it can be disable with SKIP_CFG2HTML
#

if test -z "$SKIP_CFG2HTML" && type -p cfg2html >/dev/null ; then

	ProgressStart "Collecting general system information (cfg2html)"

	# cfg2html recommend to keep the result private
	mkdir -v -p -m 0750 $VAR_DIR/recovery/cfg2html 1>&8
	ProgressStopIfError $? "Could not create '$VAR_DIR/recovery/cfg2html' directory"
	# use an installed cfg2html if available:
	cfg2html -o $VAR_DIR/recovery/cfg2html -p | ProgressStepSingleChar
	
	ProgressStop
	
	# add HTML part of cfg2html to result files
	RESULT_FILES=( "${RESULT_FILES[@]}" $(find $VAR_DIR/recovery/cfg2html -type f -name \*.html) )
fi
