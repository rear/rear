# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# We support using cfg2html to collect general system information.
# For this cfg2html has to be installed and it has not been disabled.

# If USE_CFG2HTML is disabled, skip this script
if ! is_true "$USE_CFG2HTML" ; then
    return
fi

#if [[ ! "$USE_CFG2HTML" =~ ^[yY1] ]]; then
#    return
#fi

# If SKIP_CFG2HTML is enabled, skip this script (backward compatibility)
# we promised to drop SKIP_CFG2HTML from 1.18 on
#if [[ -z "$USE_CFG2HTML" && -z "$SKIP_CFG2HTML" ]]; then
#    return
#fi

# No cfg2html binary, skip this script
if ! has_binary cfg2html; then
    Log "cfg2html has not been found on the system, skipping cfg2html."
    return
fi

Log "Collecting general system information (cfg2html)"

# cfg2html recommend to keep the result private
mkdir -p $v -m0750 $VAR_DIR/recovery/cfg2html >&2
StopIfError "Could not create '$VAR_DIR/recovery/cfg2html' directory"

cfg2html -p -o $VAR_DIR/recovery/cfg2html >/dev/null
LogIfError "Errors occurred when running cfg2html (see $VAR_DIR/recovery/cfg2html/$HOSTNAME.err)"

# Add HTML part of cfg2html to result files
RESULT_FILES=( "${RESULT_FILES[@]}" $(find $VAR_DIR/recovery/cfg2html -type f -name \*.html) )
