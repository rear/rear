# 560_check_bareos_filesets.sh

[[ ! -z "$BAREOS_FILESET" ]] && return   # variable filled in already (via local.conf?)

# echo "show filesets" | bconsole | grep "Name =" | grep $HOSTNAME | cut -d= -f2
# "client-fileset"
# "client-fileset-mysql"

# if we have more then 1 fileset for a client
# then we need also to define variable BAREOS_FILESET

# Save the found fileset names in a file
echo ".filesets" | bconsole | grep $HOSTNAME > "$TMP_DIR/bareos_filesets"
nr_of_filesets=( $(wc -l $TMP_DIR/bareos_filesets) )

case "$nr_of_filesets" in
    0 ) Error "No fileset defined in Bareos for $HOSTNAME" ;;
    1 ) BAREOS_FILESET="$(cat $TMP_DIR/bareos_filesets)"
        Log "We found Bareos fileset : $BAREOS_FILESET"
        echo "BAREOS_FILESET=$BAREOS_FILESET" >> $VAR_DIR/bareos.conf
        ;;
    * ) LogPrint "We found several defined Bareos filesets for $HOSTNAME :"
        LogPrint "$( cat $TMP_DIR/bareos_filesets | sed -e 's/"//g' )"
        Error "Define variable BAREOS_FILESET in $CONFIG_DIR/local.conf" ;;
esac
