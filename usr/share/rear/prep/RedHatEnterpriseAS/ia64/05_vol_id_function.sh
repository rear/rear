# udev-039-10.15.EL4 contains a criple udev_volume_id and no vol_id 
# The usage of udev_volume_id is as follows:
# export DEVPATH=/block/sdb/sdb2
# udev_volume_id
# F:filesystem
# T:ext3
# V:
# L:/1
# N:1
# U:ee45e033-277c-45c9-b708-6d7ba5b01db3

#
if $(which vol_id >/dev/null 2>&1) ; then
      # nothing
        :
else
	Log "Required udev program 'udev_volume_id' found,  but needs DEVPATH to work properly!
Activating a very primitive builtin replacement that supports 
ext2/3:   LABEL and UUID
reiserfs: LABEL
xfs:      LABEL and UUID
vfat:	  EFI 
swap:     LABEL

WARNING: This replacement is a best effort only! Please upgrade udev if possible.
"
	function vol_id {
		case "$(file -sbL "$1")" in
		*ext*filesystem*)
			echo "ID_FS_USAGE='filesystem'"
			while IFS=: read key val junk ; do
				val="${val#* }"
				case "$key" in
				*features*)
					if expr match "$val" has_journal >/dev/null ; then
						echo "ID_FS_TYPE='ext3'"
					else
						echo "ID_FS_TYPE='ext2'"
					fi
					;;
				*name*)
					echo "ID_FS_LABEL='$val'"
					;;
				*UUID*)
					echo "ID_FS_UUID='$val'"
					;;
				esac
			done < <(tune2fs -l "$1")
			;;
		*ReiserFS*)
			echo "ID_FS_USAGE='filesystem'"
			echo "ID_FS_TYPE='reiserfs'"
			echo "ID_FS_LABEL='$(dd if="$1" bs=1 skip=$((0x10064)) count=64 2>/dev/null)'"
			;;
		*XFS*)
			echo "ID_FS_USAGE='filesystem'"
			echo "ID_FS_TYPE='xfs'"
			echo "ID_FS_LABEL='$(xfs_admin -l "$1" | cut -d \" -f 2)'"
			echo "ID_FS_UUID=''$(xfs_admin -u "$1" | cut -d " " -f 3)'"
			;;
		*FAT*)
			echo "ID_FS_USAGE='filesystem'"
			echo "ID_FS_TYPE='vfat'"
			;;
		*swap*file*|*data*)
			echo "ID_FS_USAGE='other'"
			echo "ID_FS_TYPE='swap'"
			echo "ID_FS_VERSION='2'"
			echo "ID_FS_LABEL='$(dd if="$1" bs=1 skip=$((0x41c)) count=64 2>/dev/null)'"
			;;
		*)
			Error "Unsupported filesystem found on '$1'
file says: $(file -sbL "$1")
You might try to install the proper vol_id from the udev package to support
this filesystem."
		esac
	}
fi
