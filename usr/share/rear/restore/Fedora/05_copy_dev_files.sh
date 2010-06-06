# CentOS uses udev with a tmpfs mounted on /dev
# Most backup software thus fails to backup /dev
# Therefore /dev stays empty after the restore, which prevents us from installing the boot loader
#
# The solution is to copy a rudimentary set of /dev entries into the restored system
# We take these from the rescue system.

cp -a /dev/. /mnt/local/dev/
