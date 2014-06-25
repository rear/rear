# restore files with TSM
# have to do this for each filespace
#-----<--------->-------
export starposition=1
star ()
{
    set -- '/' '-' '\' '|';
    test $starposition -gt 4 -o $starposition -lt 1 && starposition=1;
    echo -n "${!starposition}";
    echo -en "\r";
    let starposition++
    #sleep 0.1
}
#-----<--------->-------

for num in $TSM_RESTORE_FILESPACE_NUMS ; do
    filespace="${TSM_FILESPACES[$num]}"
    # make sure FileSpace has a trailing / (for dsmc)
    test "${filespace:0-1}" == "/" || filespace="$filespace/"
    LogPrint "Restoring ${filespace}"
    TsmProcessed=""
    Log "Running 'dsmc restore ${filespace}* /mnt/local/$filespace -verbose -subdir=yes -replace=all -tapeprompt=no ${TSM_DSMC_RESTORE_OPTIONS[@]}'"
    LC_ALL=${LANG_RECOVER} dsmc restore \""${filespace}"\" \""/mnt/local/${filespace}/"\"  \
        -verbose -subdir=yes -replace=all \
        -tapeprompt=no "${TSM_DSMC_RESTORE_OPTIONS[@]}" | \
    while read Line ; do
        if test "${Line:0:8}" == "ANS1898I" ; then
            TsmProcessed="$(echo "${Line:9}" | tr -s '*') "
            Line="Restoring" # trigger star
        fi
        if test "${Line:0:9}" == "Restoring" ; then
            echo -n "$TsmProcessed"
            star
        else
            echo "$Line"
        fi
    done
done

