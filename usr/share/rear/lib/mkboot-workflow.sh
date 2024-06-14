# mkboot-workflow.sh
#
# mkboot workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# According to https://github.com/rear/rear/pull/2965 
# the mkboot workflow is not for normal usage but for testing and development
# see https://github.com/rear/rear/pull/2965#issue-1651096154
#  "mkboot workflow for bare boot image without rescue info
#   (for testing stuff not related to backup/restore)"
# and https://github.com/rear/rear/pull/2965#issuecomment-1511613739
#  "mkboot allows me to create a generic boot media
#   without caring about a backup method or rescue stuff,
#   super useful for working on a feature like Python that doesn't depend on anything"
# so we list the mkboot workflow only when "rear help" is called in verbose mode:
test "$VERBOSE" && WORKFLOW_mkboot_DESCRIPTION="create boot media without recovery information (for testing and development)"
WORKFLOWS+=( mkboot )
WORKFLOW_mkboot () {

	SourceStage "prep"

	SourceStage "rescue"

	SourceStage "build"

	SourceStage "pack"

	SourceStage "output"
}
