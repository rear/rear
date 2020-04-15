# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# Collect HP Smartarray information

# The define_HPSSACLI function finds the proper HP Smart Storage Administrator CLI (HPSSACLI) command and
# defines the HPSSACLI variable that contains the HP Smart Storage Administrator CLI command (without path):
define_HPSSACLI

# TODO: What if HP Smart Storage is used but no HP Smart Storage Administrator CLI command is found?
# Shouldn't then "rear mkrescue/mkbackup" better error out than to ignore that HP Smart Storage is used? 
has_binary $HPSSACLI || return 0

# Add $HPSSACLI to the rescue image (and added to REQUIRED_PROGS below when it is actually required):
PROGS+=( $HPSSACLI )
# How the "eval $(grep ON_DIR= $(get_path $HPSSACLI))" command works:
# Prerequisit: $HPSSACLI (e.g. /sbin/ssacli) is a shell script.
# That $HPSSACLI script contains a command (e.g. in case of /sbin/ssacli) like
#   export SSACLI_BIN_INSTALLATION_DIR=/opt/smartstorageadmin/ssacli/bin/
# This command is searched for with "grep ON_DIR="
# executed with eval so that the variable therein gets set
# which is finally used/evaluated in the COPY_AS_IS array setting
# cf. https://github.com/rear/rear/pull/1759#discussion_r175835287
eval $(grep ON_DIR= $(get_path $HPSSACLI))
COPY_AS_IS+=( "$HPACUCLI_BIN_INSTALLATION_DIR" "$HPSSACLI_BIN_INSTALLATION_DIR" "$SSACLI_BIN_INSTALLATION_DIR")

# determine the version of HPSSACLI - required to know for a bug with version '9.30.15' (see issue #455)
HPSSACLI_VERSION=$( get_version $HPSSACLI version )

Log "Saving HP SmartArray configuration."

### In case we have a controller problem, the $HPSSACLI output may not reflect
### the actual configuration of the system, and hence the layout output could
### be incorrect ! Fail if this is the case !
$HPSSACLI ctrl all show detail > $TMP_DIR/hpraid-detail.tmp
grep 'Controller Status:' $TMP_DIR/hpraid-detail.tmp | grep -v 'Controller Status: OK'
if (( $? != 1 )); then
    Error "One or more HP SmartArray controllers have errors, fix this first !"
fi

echo "$HPSSACLI_VERSION" | grep -q '9.30.15'
if [[ $? -eq 0 ]]; then
    # see issue #455 - due to a bug in hpssacl version 9.30.15 we need to list it different
    for slotnr in $( $HPSSACLI controller all show | grep Slot | sed -r 's/.*Slot ([0-9]).*/\1/' )
    do
        # we want the order as Slot, array, logicaldrive, physicaldrive (see issue #208)
        $HPSSACLI controller slot=$slotnr ld all show >> $TMP_DIR/hpraid-config.tmp
        $HPSSACLI controller slot=$slotnr pd all show | grep physicaldrive >> $TMP_DIR/hpraid-config.tmp
    done
else
    $HPSSACLI ctrl all show config > $TMP_DIR/hpraid-config.tmp
fi


# a list of all non-empty controllers
controllers=()

write_logicaldrive() {
    if [ -n "$drives" ] ; then
        echo "logicaldrive $devname $slotnr|$arrayname|$ldname raid=$raidlevel drives=$drives spares=$spares sectors=$sectors stripesize=$stripesize" >> $DISKLAYOUT_FILE
        # We only want controllers that have a logical drive in the layout file.
        if ! IsInArray "$slotnr" "${controllers[@]}" ; then
            controllers+=( "$slotnr" )
        fi
    fi
    drives=""
    spares=""
}

drives=
spares=

while read line ; do
    case $line in
        *Slot*)
            nextslotnr=$(echo "$line" | sed -r 's/.*Slot ([0-9]).*/\1/')
            ;;
        *array*)
            nextarrayname=$(echo "$line" | sed -r 's/.*array ([A-Z]).*/\1/')
            ;;
        *logicaldrive*)
            # Write previously found logical drive
            write_logicaldrive
            slotnr=$nextslotnr
            arrayname=$nextarrayname

            # Create new Logical drive
            drivedetails=$(echo "$line" | sed -r 's/.*logicaldrive ([^ ]+) .*RAID ([^ ,]+)[ ,]+.*/\1 \2/')
            raidlevel=${drivedetails#* }
            ldname=${drivedetails% *}

            tmpfile=$TMP_DIR/ctrl$slotnr-$ldname.tmp
            $HPSSACLI ctrl slot=$slotnr ld $ldname show detail > $tmpfile
            stripesize=$(grep -i "stripe" $tmpfile | sed -r "s/[^0-9]+([0-9]+).*/\1/")
            sectors=$(grep -i "sectors" $tmpfile | sed -r "s/[^0-9]+([0-9]+).*/\1/")
            devname=$(grep -i "name" $tmpfile | cut -d ":" -f "2" | tr -d " ")
            ;;
        *physicaldrive*)
            if [ -n "$arrayname" ] ; then
                pdname=$(echo "$line" | sed -r 's/.*physicaldrive ([^ ]+) .*/\1/')
                if echo "$line" | grep -q spare ; then
                    spares="${spares}${pdname},"
                else
                    drives="${drives}${pdname},"
                fi
            fi
            ;;
        *unassigned*)
            break
            ;;
    esac
done < $TMP_DIR/hpraid-config.tmp
write_logicaldrive

for controller in "${controllers[@]}" ; do
    echo "smartarray $controller" >> $DISKLAYOUT_FILE
done

# The HP Smart Storage Administrator CLI command $HPSSACLI (from the define_HPSSACLI function in lib/hp_raid-functions.sh)
# is required in the recovery system if disklayout.conf contains at least one 'logicaldrive' or 'smartarray' entry
# see the create_logicaldrive and create_smartarray functions in layout/prepare/GNU/Linux/170_include_hpraid_code.sh
# what program calls are written to diskrestore.sh
# cf. https://github.com/rear/rear/issues/1963
egrep -q '^logicaldrive |^smartarray ' $DISKLAYOUT_FILE && REQUIRED_PROGS+=( $HPSSACLI ) || true

