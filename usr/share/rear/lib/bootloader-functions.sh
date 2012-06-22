function get_syslinux_version {
    local syslinux_version

    # Test for the syslinux version
    syslinux_version=$(get_version extlinux --version)
    if [[ -z "$syslinux_version" ]]; then
        syslinux_version=$(get_version syslinux --version)
    fi

    if [[ -z "$syslinux_version" ]]; then
        syslinux_version=$(strings $SYSLINUX_DIR/isolinux.bin | grep ISOLINUX | head -1 | cut -d' ' -f2)
    fi

    if [[ -z "$syslinux_version" ]]; then
        Log "Could not detect syslinux version, assuming it is old"
    fi

    echo "$syslinux_version"
}

function set_syslinux_features {
	# Test for features in syslinux
	# true if isolinux supports booting from /boot/syslinux, /boot or only from / of the ISO
	FEATURE_ISOLINUX_BOOT_SYSLINUX=
	# true if syslinux supports booting from /boot/syslinux, /boot or only from / of the USB media
	FEATURE_SYSLINUX_BOOT_SYSLINUX=
	# true if syslinux and extlinux support localboot
	FEATURE_SYSLINUX_EXTLINUX_WITH_LOCALBOOT=
	# true if extlinux supports the -i option
	FEATURE_SYSLINUX_EXTLINUX_INSTALL=
	# true if syslinux supports INCLUDE directive
	FEATURE_SYSLINUX_INCLUDE=
	# true if syslinux supports advanced label names (eg. linux-2.6.18)
	FEATURE_SYSLINUX_LABEL_NAMES=
	# true if syslinux supports MENU DEFAULT directive
	FEATURE_SYSLINUX_MENU_DEFAULT=
	# true if syslinux supports MENU HELP directive
	FEATURE_SYSLINUX_MENU_HELP=
	# true if syslinux supports MENU BEGIN/MENU END/MENU QUIT directives
	FEATURE_SYSLINUX_SUBMENU=
	# true if syslinux supports MENU HIDDEN directive
	FEATURE_SYSLINUX_MENU_HIDDEN=
	# true if syslinux supports TEXT HELP directive
	FEATURE_SYSLINUX_TEXT_HELP=

	# Define the syslinux directory for later usage
	if [[ -z "$SYSLINUX_DIR" ]]; then
		for file in /usr/{share,lib,libexec}/*/isolinux.bin ; do
			if [[ -s "$file" ]]; then
				SYSLINUX_DIR="$(dirname $file)"
				break # for loop
			fi
		done
	fi
	[[ "$SYSLINUX_DIR" ]]
	StopIfError "Could not find a working syslinux path."

	local syslinux_version=$(get_syslinux_version)
	if [[ "$1" ]] && version_newer "$1" "$syslinux_version"; then
		syslinux_version="$1"
	fi
	Log "Features based on syslinux version: $syslinux_version"

	if version_newer "$syslinux_version" 4.00; then
		FEATURE_SYSLINUX_MENU_HELP="y"
		FEATURE_ISOLINUX_BOOT_SYSLINUX="y"
	fi
	if version_newer "$syslinux_version" 3.72; then
		FEATURE_SYSLINUX_MENU_DEFAULT="y"
	fi
	if version_newer "$syslinux_version" 3.70; then
		FEATURE_SYSLINUX_EXTLINUX_WITH_LOCALBOOT="y"
	fi
	if version_newer "$syslinux_version" 3.62; then
		FEATURE_SYSLINUX_SUBMENU="y"
	fi
	if version_newer "$syslinux_version" 3.52; then
		FEATURE_SYSLINUX_MENU_HIDDEN="y"
	fi
	if version_newer "$syslinux_version" 3.50; then
		FEATURE_SYSLINUX_INCLUDE="y"
		FEATURE_SYSLINUX_TEXT_HELP="y"
	fi
	if version_newer "$syslinux_version" 3.35; then
		FEATURE_SYSLINUX_BOOT_SYSLINUX="y"
		FEATURE_SYSLINUX_LABEL_NAMES="y"
	fi
	if version_newer "$syslinux_version" 3.20; then
		FEATURE_SYSLINUX_EXTLINUX_INSTALL="y"
	fi

	if [[ "$FEATURE_SYSLINUX_BOOT_SYSLINUX" ]]; then
		SYSLINUX_PREFIX="boot/syslinux"
	else
		SYSLINUX_PREFIX=
	fi
	Log "Using syslinux prefix: $SYSLINUX_PREFIX"

	FEATURE_SYSLINUX_IS_SET=1
}



# Create a suitable syslinux configuration based on capabilities
# the mandatory first argument is the full path to an existing directory where required
# binaries will be copied to
# the optional second argment is the target flavour and defaults to isolinux
function make_syslinux_config {
	[[ -d "$1" ]]
	BugIfError "Required argument for BOOT_DIR is missing"
	[[ -d "$SYSLINUX_DIR" ]]
	BugIfError "Required environment SYSLINUX_DIR ($SYSLINX_DIR) is not set or not a d irectory"
	[[ "$FEATURE_SYSLINUX_IS_SET" ]]
	BugIfError "You must call set_syslinux_features before"

	local BOOT_DIR="$1" ; shift
	local flavour="${1:-isolinux}" ; shift

    # Enable serial console, unless explicitly disabled (only last entry is used :-/)
    if [[ "$USE_SERIAL_CONSOLE" =~ ^[yY1] ]]; then
        for devnode in $(ls /dev/ttyS[0-9]* | sort); do
            speed=$(stty -F $devnode 2>&8 | awk '/^speed / { print $2 }')
            if [ "$speed" ]; then
                echo "serial ${devnode##/dev/ttyS} $speed"
            fi
        done
    fi

	# if we have the menu.c32 available we use it. if not we make sure that there will be no menu lines in the result
	# so that we don't confuse older syslinux
	if [[ -r "$SYSLINUX_DIR/menu.c32" ]] ; then
		cp $v "$SYSLINUX_DIR/menu.c32" "$BOOT_DIR/menu.c32" >&2
		function syslinux_menu {
			echo "MENU $@"
		}
	else
		# without menu we don't set a default but we ask syslinux to prompt for user input
		echo "prompt 1"
		function syslinux_menu {
			: #noop
		}
	fi

	function syslinux_menu_help {
		if [[ "$FEATURE_SYSLINUX_MENU_HELP" ]]; then
			echo "TEXT HELP"
			for line in "$@" ; do echo "$line" ; done
			echo "ENDTEXT"
		fi
	}

	echo "say ENTER - boot local hard disk"
	echo "say --------------------------------------------------------------------------------"
	echo "$VERSION_INFO" >$BOOT_DIR/message
	echo "display message"
	echo "F1 message"

	if [[ -s "$CONFIG_DIR/templates/rear.help" ]]; then
		cp $v "$CONFIG_DIR/templates/rear.help" "$BOOT_DIR/rear.help" >&2
		echo "F2 rear.help"
		echo "say F2 - Show help"
		syslinux_menu "TABMSG Press [Tab] to edit, [F2] for help, [F1] for version info"
	else
		syslinux_menu "TABMSG Press [Tab] to edit options and [F1] for version info"
	fi

	echo "timeout 300"
	echo "#noescape 1"
	syslinux_menu title $PRODUCT v$VERSION

	echo "say rear - Recover $(uname -n)"
	echo "label rear"
	syslinux_menu "label ^Recover $(uname -n)"
	syslinux_menu_help "Rescue image kernel $KERNEL_VERSION ${IPADDR:+on $IPADDR} $(date -R)" \
			"${BACKUP:+BACKUP=$BACKUP} ${OUTPUT:+OUTPUT=$OUTPUT} ${BACKUP_URL:+BACKUP_URL=$BACKUP_URL}"
	echo "kernel kernel"
	echo "append initrd=initrd.cgz root=/dev/ram0 vga=normal rw $KERNEL_CMDLINE"

	syslinux_menu separator
	echo "label -"
	syslinux_menu "label Other actions"
	syslinux_menu "disable"
	echo ""

	if [[ "$FEATURE_SYSLINUX_MENU_HELP" && -r "$CONFIG_DIR/templates/rear.help" ]]; then
		echo "label help"
		syslinux_menu "label ^Help for $PRODUCT"
		syslinux_menu_help "More information about Relax-and-Recover and the steps for recovering your system"
		syslinux_menu "help rear.help"
	fi

	# Use chain booting for booting disk, if chain.c32 is available
	if [[ -r "$SYSLINUX_DIR/chain.c32" ]]; then
		cp $v "$SYSLINUX_DIR/chain.c32" "$BOOT_DIR/chain.c32" >&2

		echo "say boothd0 - boot first local disk"
		echo "label boothd0"
		syslinux_menu "label Boot First ^Local disk (hd0)"
		if [ "$flavour" == "isolinux" ] ; then
			# for isolinux local boot means boot from first disk
			echo "default boothd0"
			syslinux_menu "default"
		fi
		echo "kernel chain.c32"
		echo "append hd0"
		echo ""

		echo "say boothd1 - boot second local disk"
		echo "label boothd1"
		syslinux_menu "label Boot ^Second Local disk (hd1)"
		if [[ "$flavour" == "extlinux" ]]; then
			# for extlinux local boot means boot from second disk because the boot disk became the first disk
			# which usually allows us to access the original first disk as second disk
			echo "default boothd1"
			syslinux_menu "default"
		fi
		echo "kernel chain.c32"
		echo "append hd1"
		echo ""

	fi

	if [[ "$flavour" != "extlinux" || "$FEATURE_SYSLINUX_EXTLINUX_WITH_LOCALBOOT" ]]; then
		# localboot is a isolinux and pxelinux feature only, see http://syslinux.zytor.com/wiki/index.php/SYSLINUX#LOCALBOOT_type_.5BISOLINUX.2C_PXELINUX.5D
		# but extlinux >= 3.70 actually also supports localboot, see http://syslinux.zytor.com/wiki/index.php/Syslinux_3_Changelog#Changes_in_3.70

		if [[ ! -r "$SYSLINUX_DIR/chain.c32" ]]; then
			# this should be above under the if chain.c32 section but it comes here because it will work only if localboot is supported
			# if you use old extlinux then you just cannot boot from other device unless chain.c32 is available :-(
			echo "say boot80 - Boot from first BIOS disk 0x80"
			echo "label boot80"
			syslinux_menu "label Boot First ^Local BIOS disk (0x80)"
			if [[ "$flavour" == "isolinux" ]]; then
				# for isolinux local boot means boot from first disk
				echo "default boot80"
				syslinux_menu default
			fi
			echo "localboot 0x80"
			echo
			echo "say boot81 - Boot from second BIOS disk 0x81"
			echo "label boot81"
			syslinux_menu "label Boot Second ^Local BIOS disk (0x81)"
			if [[ "$flavour" == "extlinux" ]]; then
				# for extlinux local boot means boot from second disk because the boot disk became the first disk
				# which usually allows us to access the original first disk as second disk
				echo "default boot81"
				syslinux_menu default
			fi
			echo "localboot 0x81"
			echo ""
		fi

		echo "say local - Boot from next boot device"
		echo "label local"
		syslinux_menu "label Boot ^Next device"
		syslinux_menu_help "Boot from the next device in the BIOS boot order list."
		if [[ "$flavour" == "pxelinux" ]]; then
			echo "localboot 0"
		else
			# iso/extlinux support -1 for try next boot device
			echo "localboot -1"
		fi
		echo ""
	fi

	if [[ -r "$SYSLINUX_DIR/hdt.c32" ]]; then
		cp $v "$SYSLINUX_DIR/hdt.c32" "$BOOT_DIR/hdt.c32" >&2
		if [[ -r "/usr/share/hwdata/pci.ids" ]]; then
			cp $v "/usr/share/hwdata/pci.ids" "$BOOT_DIR/pci.ids" >&2
		elif [[ -r "/usr/share/pci.ids" ]]; then
			cp $v "/usr/share/pci.ids" "$BOOT_DIR/pci.ids" >&2
		fi
		if [[ -r "/lib/modules/$KERNEL_VERSION/modules.pcimap" ]]; then
			cp $v "/lib/modules/$KERNEL_VERSION/modules.pcimap" "$BOOT_DIR/modules.pcimap" >&2
		fi
		echo "say hdt - Hardware Detection Tool"
		echo "label hdt"
		syslinux_menu "label ^Hardware Detection Tool"
		syslinux_menu_help "Information about your current hardware configuration"
		echo "kernel hdt.c32"
		echo ""
	fi

	# You need the memtest86+ package installed for this to work
	MEMTEST_BIN=$(ls -d /boot/memtest86+-* 2>&8 | tail -1)
	if [[ "$MEMTEST_BIN" != "." && -r "$MEMTEST_BIN" ]]; then
		cp $v "$MEMTEST_BIN" "$BOOT_DIR/memtest" >&2
		echo "memtest - Run memtest86+"
		echo "label memtest"
		syslinux_menu "label ^Memory test"
		syslinux_menu_help "Test your memory for problems with memtest86+"
		echo "kernel memtest"
		echo "append -"
		echo ""
	fi

	if [[ -r "$SYSLINUX_DIR/reboot.c32" ]] ; then
		cp $v "$SYSLINUX_DIR/reboot.c32" "$BOOT_DIR/reboot.c32" >&2
		echo "say reboot - Reboot the system"
		echo "label reboot"
		syslinux_menu "label Re^Boot system"
		syslinux_menu_help "Reboot the system now"
		echo "kernel reboot.c32"
		echo ""
	fi

	if [[ -r "$SYSLINUX_DIR/poweroff.com" ]]; then
		cp $v "$SYSLINUX_DIR/poweroff.com" "$BOOT_DIR/poweroff.com" >&2
		echo "say poweroff - Poweroff the system"
		echo "label poweroff"
		syslinux_menu "label ^Power off system"
		syslinux_menu_help "Power off the system now"
		echo "kernel poweroff.com"
		echo ""
	fi

	if [[ -r "$SYSLINUX_DIR/menu.c32" ]]; then
		echo "default menu.c32"
	fi
}
