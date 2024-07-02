
# config-functions.sh
#
# configuration functions for Relax-and-Recover
#

# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# Find out which OS vendor and version we run on (openSUSE, SLES, RHEL, Fedora, Debian, ...)
function SetOSVendorAndVersion () {

    # If these variables are already set, skip doing it again.
    # This is needed, so that they can be overridden in $WORKFLOW.conf
    # if this happens, then ALL the variables OS_* have to be set there.
    # The test must match OS_VENDOR=generic or OS_VERSION=none in default.conf:
    if test "$OS_VENDOR" = generic -o "$OS_VERSION" = none ; then

        # Recent Linux distros with systemd have the /etc/os-release file
        # Try to find all the required information from that file
        if [[ -f /etc/os-release ]] ; then
            local ID ID_LIKE
            eval "$(grep "^ID=" /etc/os-release)"
            eval "$(grep "^ID_LIKE=" /etc/os-release)"

            # Deal with derivatives first:
            case "$ID_LIKE" in
                (*arch*)
                    OS_VENDOR=Arch_Linux
                    ;;
                (*centos*|*rhel*)
                    OS_VENDOR=RedHatEnterpriseServer
                    ;;
                (*debian*)
                    OS_VENDOR=Debian
                    ;;
                # Fedora must be after RHEL to distinguish RHEL derivatives.
                (*fedora*)
                    OS_VENDOR=Fedora
                    ;;
                (*suse*)
                    OS_VENDOR=SUSE_LINUX
                    ;;
                (*ubuntu*)
                    OS_VENDOR=Ubuntu
                    ;;
            esac

            # And then use the actual ID.  This may reset OS_VENDOR if it was
            # already set. E.g. Ubuntu is like Debian but ReaR treats it as
            # a separate OS_VENDOR.
            case "$ID" in
                (arch)
                    OS_VENDOR=Arch_Linux
                    ;;
                (debian)
                    OS_VENDOR=Debian
                    ;;
                (fedora)
                    OS_VENDOR=Fedora
                    ;;
                (rhel|ol)
                    # Oracle Linux specifies only Fedora and not RHEL in ID_LIKE=
                    OS_VENDOR=RedHatEnterpriseServer
                    ;;
                (suse)
                    OS_VENDOR=SUSE_LINUX
                    ;;
                (ubuntu)
                    OS_VENDOR=Ubuntu
                    ;;
            esac

            local VERSION_ID
            eval "$(grep "^VERSION_ID=" /etc/os-release)"
            contains_visible_char "$VERSION_ID" && OS_VERSION="$VERSION_ID"
        fi

        # For non-systemd distro's try the /etc/system-release file
        if test "$OS_VENDOR" = generic ; then
            if [[ -f /etc/system-release ]] ; then
                grep -q -i 'fedora' /etc/system-release && OS_VENDOR=Fedora
                grep -q -i -E '(centos|redhat|scientific|oracle)' /etc/system-release && OS_VENDOR=RedHatEnterpriseServer
                grep -q -i 'suse' /etc/system-release && OS_VENDOR=SUSE_LINUX
                grep -q -i 'mandriva' /etc/system-release && OS_VENDOR=Mandriva
                majornr=$( grep -o -E '[0-9]+' /etc/system-release | head -1 )
                minornr=$( grep -o -E '[0-9]+' /etc/system-release | head -2 | tail -1 )
                OS_VERSION="$majornr.$minornr"
            fi
        fi

        # For older distro's we try to interprete the /etc/SuSE-release or /etc/redhat-release file
        # The /etc/issue file cannot be trusted as it can contain customer related info instead of release info
        if test "$OS_VENDOR" = generic ; then
            if [[ -f /etc/SuSE-release ]] ; then
                OS_VENDOR=SUSE_LINUX
                majornr=$( grep VERSION /etc/SuSE-release | awk '{print $3}' )
                minornr=$( grep PATCHLEVEL /etc/SuSE-release | awk '{print $3}' )
                OS_VERSION="$majornr.$minornr" 
            fi

            if [[ -f /etc/redhat-release ]] ; then
                OS_VENDOR=RedHatEnterpriseServer
                majornr=$( grep -o -E '[0-9]+' /etc/system-release | head -1 )
                minornr=$( grep -o -E '[0-9]+' /etc/system-release | head -2 | tail -1 )
                OS_VERSION="$majornr.$minornr"
            fi

            if [[ -f /etc/slackware-version ]] ; then
                OS_VENDOR=Slackware
                OS_VERSION=$(cat /etc/slackware-version  | sed -r -e 's/slackware\s*//i')
            fi
        fi

        # If OS_VENDOR is still generic then use as last resource 'lsb_release' to find out
        if test "$OS_VENDOR" = generic ; then
            # When OS_VENDOR is still "generic" we are using a pre-systemd system and need to fallback
            # to lsb_release, therefore, as it is not a required binary we will check if we have this
            # executable and when absent bail out with an error
            if ! has_binary lsb_release ; then
                Error "The 'lsb_release' command cannot be run.
Detecting the operating system and its version requires LSB support.
Install a software package that provides the 'lsb_release' command.
Alternatively you can manually specify OS_VENDOR and OS_VERSION in
'$CONFIG_DIR/os.conf' and verify that your setup actually works.
See '$SHARE_DIR/lib/config-functions.sh' for more details."
           fi

            OS_VENDOR="$( lsb_release -i -s | tr -s '[:blank:]' '_' )"
            test "$OS_VENDOR" || Error "Failed to detect OS_VENDOR. You may manually specify it in $CONFIG_DIR/os.conf"
            # For all SUSE distributions (SLES and openSUSE) ReaR uses
            # only .../SUSE_LINUX/... sub-directories plus conf/SUSE_LINUX.conf
            # so that 'lsb_release -i -s' output must be unified to 'SUSE_LINUX'.
            # For example 'lsb_release -i -s' outputs
            # on SLES11 SP3 : 'SUSE LINUX'
            # on SLES12 12 SP2 : 'SUSE'
            # on openSUSE Leap 42.1 : 'SUSE LINUX'
            # on openSUSE Tumbleweed 20170304 : 'openSUSE'
            # so that the common substring is 'SUSE'.
            # When OS_VENDOR contains the substring 'SUSE', set OS_VENDOR to 'SUSE_LINUX':
            test "${OS_VENDOR#*SUSE}" = "$OS_VENDOR" || OS_VENDOR="SUSE_LINUX"
            
            OS_VERSION="$( lsb_release -r -s | tr -s '[:blank:]' '_' )"
            test "$OS_VERSION" || Error "Failed to detect OS_VERSION. You may manually specify it in $CONFIG_DIR/os.conf"
        fi

    fi

    # combined stuff
    OS_VENDOR_VERSION="$OS_VENDOR/$OS_VERSION"
    OS_VENDOR_ARCH="$OS_VENDOR/$MACHINE"
    OS_VENDOR_VERSION_ARCH="$OS_VENDOR/$OS_VERSION/$MACHINE"

    # set OS_MASTER_VENDOR in case this is a derived OS and ReaR differentiates it
    case "${OS_VENDOR,,}" in
        (*redhat*)
            OS_MASTER_VENDOR="Fedora"
            ;;
        (*ubuntu*)
            OS_MASTER_VENDOR="Debian"
            ;;
        (*)
            # set fallback values to avoid error exit for 'set -eu' because of unbound variables:
            OS_MASTER_VENDOR=""
            ;;
    esac

    # Set master version to the MAJOR release version. ReaR assumes that OS_MASTER_VERSION
    # is just the major release number extracted from OS_VERSION and not the version of the derived OS.
    # TODO: Rename the variable to be less confusing.
    OS_MASTER_VERSION="${OS_VERSION%%.*}"

    # combined stuff for OS_MASTER_*
    if [ "$OS_MASTER_VENDOR" ] ; then
        OS_MASTER_VENDOR_VERSION="$OS_MASTER_VENDOR/$OS_MASTER_VERSION"
        OS_MASTER_VENDOR_ARCH="$OS_MASTER_VENDOR/$MACHINE"
        OS_MASTER_VENDOR_VERSION_ARCH="$OS_MASTER_VENDOR/$OS_MASTER_VERSION/$MACHINE"
    else
        # set fallback values to avoid error exit for 'set -eu' because of unbound variables:
        OS_MASTER_VENDOR_VERSION="$OS_MASTER_VERSION"
        OS_MASTER_VENDOR_ARCH="$MACHINE"
        OS_MASTER_VENDOR_VERSION_ARCH="$OS_MASTER_VERSION/$MACHINE"
    fi

}

### Return the template filename
function get_template() {
    if [[ -e $CONFIG_DIR/templates/$1 ]] ; then
        echo $CONFIG_DIR/templates/$1
    else
        echo $SHARE_DIR/conf/templates/$1
    fi
}

