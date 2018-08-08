
# Check that there is a symbolic link /dev/disk/by-label/RELAXRECOVER
# that points to a block device that uses the filesystem label RELAXRECOVER.
# RELAXRECOVER is the default value of the ISO_VOLID config variable.
# If no such symbolic link exists create one because it is needed
# during "rear recover" when the recovery system ISO image content
# will be accessed via /dev/disk/by-label/RELAXRECOVER
# which is required in particular when the ISO image contains the backup.
# I.e. with BACKUP_URL=iso://... the recovery system ISO image
# gets mounted by the mount_url function in lib/global-functions.sh by
#   mount_cmd="mount /dev/disk/by-label/${ISO_VOLID} $mountpoint"
# see https://github.com/rear/rear/issues/1891
# and https://github.com/rear/rear/issues/326

# Set the ISO_VOLID config variable because in etc/scripts/system-setup
# only user and rescue configuration files are sourced (like etc/rear/local.conf)
# so that ISO_VOLID could be already set here if it is specified by the user
# but default.conf is not sourced so that there is no default value for ISO_VOLID:
test "$ISO_VOLID" || ISO_VOLID="RELAXRECOVER"

# Try to find a block device that uses the filesystem label ISO_VOLID.
# Usually "blkid -L RELAXRECOVER" results '/dev/sr0' or '/dev/sr1'
# cf. https://github.com/rear/rear/issues/1893#issuecomment-411034001
# but "blkid -L" is not supported on SLES10 (blkid is too old there)
# so that the traditional form "blkid -l -o device -t LABEL=RELAXRECOVER"
# is used which also works and is described in "man blkid" on SLES15:
relaxrecover_block_device="$( blkid -l -o device -t LABEL="$ISO_VOLID" )"

# Try to get where the symbolic link /dev/disk/by-label/ISO_VOLID points to.
# "readlink -e symlink" outputs nothing when the symlink or its target does not exist:
relaxrecover_symlink_target="$( readlink -e "/dev/disk/by-label/$ISO_VOLID" )"

# Everything is o.k. when relaxrecover_block_device and relaxrecover_symlink_target are non-empty
# and when the relaxrecover_symlink_target value is the relaxrecover_block_device value.
# Usually the right symbolic link /dev/disk/by-label/ISO_VOLID is set up automatically by udev:
test "$relaxrecover_block_device" -a "$relaxrecover_symlink_target" -a "$relaxrecover_symlink_target" = "$relaxrecover_block_device" && return

# Something is not o.k. when we are here.
# Regardless what exactly is not o.k. there is no valid symbolic link /dev/disk/by-label/ISO_VOLID
# that points to a block device that uses the filesystem label ISO_VOLID
# so that we try to create such a symbolic link now.

# One of the things that could be not o.k. is that there is no /dev/disk/by-label/ directory.
# Usually udev would automatically create it but sometimes that does not work,
# cf. https://github.com/rear/rear/issues/1891#issuecomment-411027324
# so that we create a /dev/disk/by-label/ directory if it is not there:
mkdir -p /dev/disk/by-label

if test -b "$relaxrecover_block_device" ; then
    # When we found a block device that uses the filesystem label ISO_VOLID
    # we let our symbolic link point to that block device and then things should be o.k.:
    ln -s "$relaxrecover_block_device" "/dev/disk/by-label/$ISO_VOLID" && return
else
    # We found no block device that uses the filesystem label ISO_VOLID
    # which is considered to be a sufficiently severe issue to inform the user:
    echo "No block device with ISO filesystem label '$ISO_VOLID' found (by the blkid command)"
fi

# At this point we found no block device that uses the filesystem label ISO_VOLID
# or we found one but it failed to let our symbolic link point to it:
echo "A symlink '/dev/disk/by-label/$ISO_VOLID' is needed that points to the block device where the ISO is attached to"

# The url_scheme function was sourced by etc/scripts/system-setup.d/00-functions.sh
# and BACKUP_URL is usually specified in the also sourced etc/rear/local.conf
backup_scheme=$( url_scheme "$BACKUP_URL" )
case $backup_scheme in
    (iso)
        echo "Backup restore will fail with 'iso' BACKUP_URL unless things got fixed before running 'rear recover'"
        ;;
    (*)
        echo "Recovery might fail without symlink '/dev/disk/by-label/$ISO_VOLID' that points where to the ISO is attached"
        ;;
esac

# Now we try some basically blind fallback actions that might help by chance:

# Check if /dev/disk/by-label/$ISO_VOLID exists (as symbolic link or in any other form).
# If yes blindly assume things are right and proceed 'bona fide':
if test -e "/dev/disk/by-label/$ISO_VOLID" ; then
    echo "A file '/dev/disk/by-label/$ISO_VOLID' exists - assuming things are right and proceeding 'bona fide'"
    return
fi

# At this point no /dev/disk/by-label/$ISO_VOLID exists so that we can "just create" it as symbolic link.
# When there is a CDROM-like block device like /dev/cdrom /dev/sr0 /dev/sr1 /dev/sr2 ...
# blindly link that to /dev/disk/by-label/$ISO_VOLID and proceed 'bona fide':
for cdrom_block_device in /dev/cdrom /dev/sr* ; do
    if test -b $cdrom_block_device ; then
        if ln -s $cdrom_block_device "/dev/disk/by-label/$ISO_VOLID" ; then
            echo "Created symlink '/dev/disk/by-label/$ISO_VOLID' that points to $cdrom_block_device"
            echo "Assuming $cdrom_block_device is the block device where the ISO is attached to and proceeding 'bona fide'"
            return
        else
            echo "Failed to created symlink '/dev/disk/by-label/$ISO_VOLID' that points to $cdrom_block_device"
        fi
    fi
done

# At this point no symbolic link /dev/disk/by-label/$ISO_VOLID was successfully created and we are at our wits' end:
echo "Proceeding 'bona fide' without symlink '/dev/disk/by-label/$ISO_VOLID' that points where to the ISO is attached"

