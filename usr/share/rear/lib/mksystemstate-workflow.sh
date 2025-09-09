# mksystemstate-workflow.sh
#
# mksystemstate workflow for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

WORKFLOW_mksystemstate_DESCRIPTION="save only system state configuration"
WORKFLOWS+=( mksystemstate )
WORKFLOW_mksystemstate () {
    SourceStage "prep/systemstate"

    SourceStage "layout/save"

    SourceStage "rescue/systemstate"

    SourceStage "build/systemstate"

    SourceStage "output/systemstate"
}
