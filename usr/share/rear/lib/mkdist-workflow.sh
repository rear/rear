# mkdist-workflow.sh
#
#
# create distribution files of rear
#

if [[ "$VERBOSE" ]]; then
	WORKFLOW_mkdist_DESCRIPTION="create tar archive using installed rear"
fi
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
	test -s contrib/rear-$VERSION.ebuild ||\
		cp $v contrib/rear-*.ebuild contrib/rear-$VERSION.ebuild >&2
	ls -l home
	StopIfError "Could not mv contrib/rear-*.ebuild"


	version_string="VERSION=\"$VERSION\""
	if ! grep '$version_string' usr/sbin/rear ; then
		Log "Patching version $version_string in $(pwd)/usr/sbin/rear"
		sed -i -e 's/^VERSION=.*$/VERSION="'"$VERSION"'"/' usr/sbin/rear
	fi

# I want the generic SPEC file to be always shipped 2009-11-16 Schlomo
	sed -i -e "s/Version:.*/Version: $VERSION/" .$SHARE_DIR/lib/rear.spec
	chmod $v 644 .$SHARE_DIR/lib/rear.spec >&2
#	cp -fp .$SHARE_DIR/lib/rear.spec $SHARE_DIR/lib/rear.spec

	# remove current recovery information (pre-1.7.15)
	rm -Rf $v .$CONFIG_DIR/recovery >&2

	# remove development files
	rm -Rf $v .project .settings .externalToolBuilders >&2

	cat <<EOF >./$CONFIG_DIR/local.conf
# sample local configuration

# Create Rear rescue media as ISO image
# OUTPUT=ISO

# optionally define (non-default) backup software, e.g. TSM, NBU, DP, BACULA
# BACKUP=TSM

# extra modules to load, the following is required on older VMware VMs
# MODULES_LOAD=( vmxnet )

# extra kernel command line, to see boot messages on the serial console (uncomment next line)
# KERNEL_CMDLINE="console=tty0 console=ttyS1"
EOF

	# this little hack writes the same content into all these files...
	cat <<EOF >./$CONFIG_DIR/templates/PXE_pxelinux.cfg
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
	LogPrint "Creating archive '$distarchive'"

	mkdir $TMP_DIR/$prod_ver -v >&8
	StopIfError "Could not mkdir $TMP_DIR/$prod_ver"

	# use tar to copy the current rear while excluding development and obsolete files
	tar -C / --exclude=hpasmcliOutput.txt --exclude=\*~ --exclude=\*.rpmsave\* \
		--exclude=\*.rpmnew\* --exclude=.\*.swp -cv \
			"/contrib/" \
			"/doc/" \
			"$SHARE_DIR" \
			"$CONFIG_DIR" \
			"$(get_path "$0")" |\
		tar -C $TMP_DIR/$prod_ver -x >&8
	StopIfError "Could not copy files to $TMP_DIR/$prod_ver"

	pushd $TMP_DIR/$prod_ver >&8
	StopIfError "Could not pushd $TMP_DIR/$prod_ver"

	WORKFLOW_mkdist_postprocess

	popd >&8
	tar -C $TMP_DIR -cvzf $distarchive $prod_ver >&8
	StopIfError "Could not create $distarchive"

}
