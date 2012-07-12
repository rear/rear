# validate-workflow.sh
#
# validate workflow for Relax-and-Recover
#
# create a validation record to submit back to the project
#
#    Relax-and-Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax-and-Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax-and-Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

WORKFLOW_validate_DESCRIPTION="submit validation information"
WORKFLOWS=( ${WORKFLOWS[@]} validate )
WORKFLOW_validate () {

	Print "
Thank you for your time and effort to try out $PRODUCT and your
willingness to report about $PRODUCT in your environment back
to us. This kind of user support is greatly appreciated and helps a lot
to improve $PRODUCT.

--- The $PRODUCT development team

	"

	read -e -p "Press ENTER to continue ..." 2>&1

	Print "
The purpose of submitting validation info is to assist you with informing us
about the correct functioning of $PRODUCT (or major parts of it) to
establish a database of validated systems and environments.

Since nobody can test everything it is sufficient if you submit information
about $PRODUCT in exactly your environment and we will combine such
reports from all users into the information published on the website and within
the validation information that you can see at the end of '$PROGRAM dump'.

Please answer the following questions and email the resulting information to
the $PRODUCT development team at <contact@relax-and-recover.org>. You
should only include information that you are willing to see published on the
$PRODUCT website and contained within $PRODUCT.

	"
	read -e -p "Press ENTER to continue ..." 2>&1

	Print "
1. Submitter
-------------------
Please tell us (if you are willing), who you are and how to reach you. If you
want to remain anonymous you can put here nothing at all or only your initials
or no email or omit your company/organisation etc. However, the more 'personal'
a testimony to $PRODUCT in your environment, the more credible it
will be...

Example: Your Name <email-address>, Company/Organisation, Country
"
	read -e -p "Submitted By: " 2>&1
	SUBMITTED_BY="$REPLY"

	Print "

2. Features
-------------------
Please tell us (as exactly as possible) about the $PRODUCT features you
actually tested in your environment. Features are output and backup methods as well
as configuration types like LVM, MD etc.

Example: LVM, MD, SCSI, $BACKUP, $OUTPUT, EMAIL, ...
"
	read -e -p "Features: " 2>&1
	FEATURES="$REPLY"

	Print "

3. Comments
-------------------
Please let us know any comments you have about $PRODUCT in your
environment that would help others to better use $PRODUCT or have
less trouble installing it or maybe simply that you employ $PRODUCT
in a very large data centre with thousands of servers and that
$PRODUCT is the central component of your disaster recovery
preparations for your data centre.

Example: Need to install binutils, wodim and syslinux manually
Example: Works out-of-the-box flawless with all features
Example: We modified path/to/file in order to support foo-bar better
"
	read -e -p "Comments: " 2>&1
	COMMENTS="$REPLY"

	Print "

Thank you very much for your information. Please copy-and-paste the part
between the two lines into an email to contact@relax-and-recover.org.
Please feel free to add anything else you want to tell us about
$PRODUCT.

----------------------------------8<------------------------------------------
Version:     $PRODUCT $VERSION / $RELEASE_DATE
Validation:  $OS_VENDOR_VERSION_ARCH
Submitted:   $SUBMITTED_BY
Date:        $(date +"%Y-%m-%d")
Features:    $FEATURES
Comment:     $COMMENTS
---------------------------------->8------------------------------------------

You can also find this information in /tmp/rear-validate.txt !

	"
	cat <<EOF >/tmp/rear-validate.txt
Version:     $PRODUCT $VERSION / $RELEASE_DATE
Validation:  $OS_VENDOR_VERSION_ARCH
Submitted:   $SUBMITTED_BY
Date:        $(date +"%Y-%m-%d")
Features:    $FEATURES
Comment:     $COMMENTS"
EOF

}
