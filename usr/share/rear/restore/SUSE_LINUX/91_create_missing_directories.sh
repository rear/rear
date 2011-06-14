#
# SuSE likes to have stuff under /media
#
# create missing directories
pushd /mnt/local >&8
mkdir -p media/cdrom media/floppy
popd >&8
