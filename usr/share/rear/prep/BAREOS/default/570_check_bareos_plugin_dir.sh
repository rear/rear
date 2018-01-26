# prep/BAREOS/default/570_check_bareos_plugin_dir.sh
# Purpose: check if the Bareos 'plugin' directory exists? If so, then add it to the COPY_AS_IS array

if [[ -d /usr/lib/bareos/plugins ]] ; then
    COPY_AS_IS=( "${COPY_AS_IS[@]}" /usr/lib/bareos/plugins )
elif [[ -d /usr/lib64/bareos/plugins ]] ; then
    COPY_AS_IS=( "${COPY_AS_IS[@]}" /usr/lib64/bareos/plugins )
fi
