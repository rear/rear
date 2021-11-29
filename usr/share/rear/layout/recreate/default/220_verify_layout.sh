#
# Verify some known things in the recreated disk layout that could go wrong
# cf. https://github.com/rear/rear/pull/2702#issuecomment-971331028
#

# Verify RAID devices are actually recreated with the UUIDs in disklayout.conf
# because mdadm silently ignores this option when creating IMSM arrays
# (both containers and the volumes inside them) and picks a random UUID
# cf. https://github.com/rear/rear/pull/2702#issuecomment-970395567

# Get recreated RAID devices.
# lsblk lists RAID devices with '*_raid_member' FSTYPE values
# e.g. 'linux_raid_member' or 'isw_raid_member' - for the latter
# see https://github.com/rear/rear/pull/2702#issuecomment-968904230
local name kname fstype uuid
local uuid_alnum_lowercase
lsblk -nrpo NAME,KNAME,FSTYPE,UUID | grep '_raid_member' | while read name kname fstype uuid ; do
    # Check recreated RAID device UUID:
    if test $uuid ; then
        # When there is a recreated RAID device with UUID
        # we grep for 'raid' entries in disklayout.conf that contain this UUID and
        # if found things are considered to be OK because UUIDs must be unique
        # so it cannot happen that a different device also has this UUID
        # i.e. we omit to check if the found UUID matches this RAID device
        # 'raid' entries in disklayout.conf contain RAID UUIDs like (excerpts)
        # raid /dev/md127 uuid=8d05eb84:2de831d1:dfed54b2:ad592118 devices=/dev/sda,/dev/sdb
        # but lsblk shows that UUID as 8d05eb84-2de8-31d1-dfed-54b2ad592118
        # so we make uuid_alnum_lowercase=8d05eb842de831d1dfed54b2ad592118
        # and make the 'raid' entries alphanumeric lowercase characters plus spaces and '=' characters
        # raid devmd127 uuid=8d05eb842de831d1dfed54b2ad592118 devices=devsdadevsdb
        # where we can grep for "uuid=$uuid_alnum_lowercase":
        uuid_alnum_lowercase="$( echo "$uuid" | tr -d -c '[:alnum:]' | tr '[:upper:]' '[:lower:]' )"
        if ! grep "^raid " $LAYOUT_FILE | tr -d -c '[:alnum:] =' | tr '[:upper:]' '[:lower:]' | grep "uuid=$uuid_alnum_lowercase" ; then
            LogPrintError "RAID device $name ($kname) recreated with UUID $uuid that is not in $LAYOUT_FILE"
        fi
    else    
        # When there is a recreated RAID device without UUID
        # we grep for 'raid' entries in disklayout.conf that contain its NAME or KNAME
        # and check if such 'raid' entries have a 'uuid=...' option set and
        # if yes we assume the recreated RAID device was falsely recreated without UUID:
        # 'raid' entries can contain RAID devices like
        # raid /dev/md127 ... devices=/dev/sda,/dev/sdb ...  uuid=...
        # raid /dev/md127 ...  uuid=... devices=/dev/sda,/dev/sdb
        # so we use end of word delimiter '\>' that matches space comma and end of line.
        # The first grep may find more than one line and the second grep may find more that one UUID.
        # Check RAID devices named NAME:
        if grep "^raid .*$name\>" $LAYOUT_FILE | grep 'uuid=' ; then
            LogPrintError "RAID device $name ($kname) recreated without UUID but there is a UUID for $name in $LAYOUT_FILE"
        fi
        # Check RAID devices named KNAME if different than NAME:
        if test "$kname" != "$name" ; then
            if grep "^raid .*$kname\>" $LAYOUT_FILE | grep 'uuid=' ; then
                LogPrintError "RAID device $kname ($name) recreated without UUID but there is a UUID for $kname in $LAYOUT_FILE"
            fi
        fi
    fi
    # Additional checks could be added here if needed:
done
