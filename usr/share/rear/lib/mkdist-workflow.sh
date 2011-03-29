# mkdist-workflow.sh
#
#
# create distribution files of rear
#

WORKFLOW_mkdist_DESCRIPTION="Create distribution tar archive with this rear version"
WORKFLOWS=( ${WORKFLOWS[@]} mkdist )

WORKFLOW_mkdist_postprocess () {
	# this function encapsulates all post-processing within the dist build tree
	# run this function after cd'ing to the dist build tree

	# YOU MUST SET THESE REQUIRED VARIABLES !!!
	# YOU MUST LOAD THE REQUIRED FUNCTIONS !!!
	# SHARE_DIR
	# CONFIG_DIR
	# VERSION

	# rename ebuild to current version if it does not have the current version
	test -s .$SHARE_DIR/contrib/rear-$VERSION.ebuild ||\
		mv -v .$SHARE_DIR/contrib/rear-*.ebuild .$SHARE_DIR/contrib/rear-$VERSION.ebuild 1>&8
	ProgressStopIfError $? "Could not mv rear-*.ebuild"


	# reverted back to symlinking because we put more MegaByte into doc and should not package it twice
	ln -s .$SHARE_DIR/{doc,contrib}  .  1>&8
	# to prevent RPMs from installing symlinks into the doc area we actually copy the text files
	cp -r .$SHARE_DIR/{COPYINGREADME,AUTHORS,TODO}  .  1>&8
	ProgressStopIfError $? "Could not copy .$SHARE_DIR/{COPYING,README,AUTHORS,TODO,doc,contrib}"
	

# I want the generic SPEC file to be always shipped 2009-11-16 Schlomo
#	# copy rear.spec according OS_VENDOR and patch version into RPM spec file
#	cp .$SHARE_DIR/lib/spec/$OS_VENDOR/rear.sourcespec .$SHARE_DIR/lib/rear.spec 1>&8
#	ProgressStopIfError $? "Could not copy $OS_VENDOR specific rear.spec file"
	sed -i -e "s/Version:.*/Version: $VERSION/" .$SHARE_DIR/lib/rear.spec
	chmod 644 .$SHARE_DIR/lib/rear.spec
#	cp -fp .$SHARE_DIR/lib/rear.spec $SHARE_DIR/lib/rear.spec

	# remove current recovery information (pre-1.7.15)
	rm -Rf .$CONFIG_DIR/recovery

	# write out standard site.conf and local.conf and templates
	cat >./$CONFIG_DIR/site.conf <<EOF
# site.conf
# another config file that is sourced BEFORE local.conf
# could be used to set site-wide settings
# you could then distribute the site.conf from a central location while you keep
# the machine-local settings in local.conf
EOF
	cat >./$CONFIG_DIR/local.conf <<EOF
# sample local configuration

# Create ReaR rescue media as ISO image
OUTPUT=ISO

# optionally define (non-default) backup software, e.g. TSM, NBU, DP, BACULA
# BACKUP=TSM

# the following is required on older VMware VMs
MODULES_LOAD=( vmxnet )

# to see boot messages on the serial console (uncomment next line)
# KERNEL_CMDLINE="console=tty0 console=ttyS1"
EOF
	
	# this little hack writes the same content into all these files...
	tee ./$CONFIG_DIR/templates/{PXE_pxelinux.cfg,ISO_isolinux.cfg} >/dev/null <<EOF
default hd
prompt 1
timeout 300

label hd
localboot -1
say ENTER - boot local hard disk
say --------------------------------------------------------------------------------
EOF


}

WORKFLOW_mkdist () {
	
	prod_ver="$(basename "$0")-$VERSION"
	distarchive="/tmp/$prod_ver.tar.gz"
	ProgressStart "Creating archive '$distarchive'"

	mkdir $BUILD_DIR/$prod_ver -v 1>&8
	ProgressStopIfError $? "Could not mkdir $BUILD_DIR/$prod_ver" 

	# use tar to copy the current rear while excluding development and obsolete files
	tar -C / --exclude=hpasmcliOutput.txt --exclude=\*~ --exclude=\*.rpmsave\* \
       		 --exclude=\*.rpmnew\* --exclude=.\*.swp -cv \
			"$SHARE_DIR" \
			"$CONFIG_DIR" \
			"$(type -p "$0")" |\
		tar -C $BUILD_DIR/$prod_ver -x 1>&8
	ProgressStopIfError $? "Could not copy files to $BUILD_DIR/$prod_ver"
	
	pushd $BUILD_DIR/$prod_ver 1>&8
	ProgressStopIfError $? "Could not pushd $BUILD_DIR/$prod_ver"

	WORKFLOW_mkdist_postprocess

	popd 1>&8
	tar -C $BUILD_DIR -cvzf $distarchive $prod_ver 1>&8
	ProgressStopOrError $? "Could not create $distarchive"

}
