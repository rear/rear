# config-functions.sh
#
# configuration functions for Relax-and-Recover
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

# find out which OS Vendor and Version we run on (SuSE, SLES, RHEL, Fedora, Debian, ...)
SetOSVendorAndVersion () {
	# if (magically) these variables are already set, skip doing it again
	# this is needed, so that they can be overridden in $WORKFLOW.conf
	# if this happens, then ALL the variables OS_* have to be set there !!
	#
	if test "$OS_VENDOR" = generic -o "$OS_VERSION" = none ; then

		# try to use lsb_release
		if has_binary lsb_release >&8 2>&1; then
			OS_VENDOR="$(lsb_release -i -s | tr -s " \t" _)"
			OS_VERSION="$(lsb_release -r -s | tr -s " \t" _)"
		else
			# we have to go the classical way
			Error "The LSB package is not installed.
	Currently there is no support to detect the OS and VERSION without LSB support.
	Please either install the LSB package (that supplies the 'lsb_release' command)
	or improve $PRODUCT to handle this situation better.

	As an alternative you can manually override OS_VENDOR and OS_VERSION in the
	'$CONFIG_DIR/os.conf' file. Please be sure to test your setup !

	See '$SHARE_DIR/lib/config-functions.sh' for more details about this matter.
"
		fi
	fi

	# combined stuff
	OS_VENDOR_VERSION="$OS_VENDOR/$OS_VERSION"
	OS_VENDOR_ARCH="$OS_VENDOR/$MACHINE"
	OS_VENDOR_VERSION_ARCH="$OS_VENDOR/$OS_VERSION/$MACHINE"

	# add OS_MASTER_* vars in case this is a derived OS
	case "$OS_VENDOR_VERSION" in
		(*Oracle*|*CentOS*|*FedoraCore*|*RedHat*|*Scientific*)
			OS_MASTER_VENDOR="Fedora"
			case "$OS_VERSION" in
				(5.*)
					# map all RHEL 5.x and clones to Fedora/5
					# this is safe because FedoraCore 5 never existed
					OS_MASTER_VERSION="5"
					;;
				(6.*)
					# map all RHEL 5.x and clones to Fedora/5
					# this is safe because FedoraCore 5 never existed
					OS_MASTER_VERSION="6"
					;;
				(*)
				OS_MASTER_VERSION="$OS_VERSION"
				;;
			esac
			;;
		(*Ubuntu*|*LinuxMint*)
			OS_MASTER_VENDOR="Debian"
			OS_MASTER_VERSION="$OS_VERSION"
			;;
		(*archlinux*)
			OS_MASTER_VENDOR="Arch"
			OS_MASTER_VERSION="$OS_VERSION"
			;;
	esac

	# combined stuff for OS_MASTER_*
	if [ "$OS_MASTER_VENDOR" ] ; then
		OS_MASTER_VENDOR_VERSION="$OS_MASTER_VENDOR/$OS_MASTER_VERSION"
		OS_MASTER_VENDOR_ARCH="$OS_MASTER_VENDOR/$MACHINE"
		OS_MASTER_VENDOR_VERSION_ARCH="$OS_MASTER_VENDOR/$OS_MASTER_VERSION/$MACHINE"
	fi

}

### Return the template filename
get_template() {
    if [[ -e $CONFIG_DIR/templates/$1 ]] ; then
        echo $CONFIG_DIR/templates/$1
    else
        echo $SHARE_DIR/conf/templates/$1
    fi
}
