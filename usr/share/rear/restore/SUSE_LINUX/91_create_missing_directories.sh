#
# SuSE likes to have stuff under /media
#
# create missing directories
pushd /mnt/local >/dev/null
for dir in media/cdrom media/floppy ; do
        mkdir -p "$dir"
done
popd >/dev/null
