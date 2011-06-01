# We support using cfg2html to collect general system information.
# For this cfg2html has to be installed and it has not been disabled.

# If USE_CFG2HTML is disabled, skip this script
if [[ ! "$USE_CFG2HTML" =~ ^[yY1] ]] then
    return
fi

# If SKIP_CFG2HTML is enabled, skip this script (backward compatibility)
if [[ -z "$USE_CFG2HTML" && -z "$SKIP2CFGHTML" ]]; then
    return
fi

# No cfg2html binary, skip this script
if type -p cfg2html &>/dev/null; then
    Log "cfg2html has not been found on the system, skipping cfg2html."
    return
fi

ProgressStart "Collecting general system information (cfg2html)"

# cfg2html recommend to keep the result private
mkdir -v -p -m0750 $VAR_DIR/recovery/cfg2html 1>&8
ProgressStopIfError $? "Could not create '$VAR_DIR/recovery/cfg2html' directory"

cfg2html -o $VAR_DIR/recovery/cfg2html -p | ProgressStepSingleChar
ProgressStopIfError $? "An error occured when running cfg2html"

ProgressStop

# Add HTML part of cfg2html to result files
RESULT_FILES=( "${RESULT_FILES[@]}" $(find $VAR_DIR/recovery/cfg2html -type f -name \*.html) )
