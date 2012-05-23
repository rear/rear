# 40_restore_with_nbu.sh
# restore files with NBU
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
Get_Start_Date ()
{
# input: $1 (file system)
# output: mm/dd/yyyy (string)
# Recent_Month_Hour="Nov 12 20:45" is a possible output
Recent_Month_Hour=""	# make it empty to start with
Recent_Month_Hour=`LANG=C /usr/openv/netbackup/bin/bplist -C ${NBU_CLIENT_SOURCE} -l -s \`date -d "-5 days" "+%m/%d/%Y"\` $1 2>&8 | head -n 1 | awk '{print $5,$6,$7}'`
[ "${Recent_Month_Hour}" ]
StopIfError "Netbackup bplist cannot get last backup timestamp of $1"

# bplist -s date_format is mm/dd/yyyy hh:mm
yyyy=`date +%Y`                                         # 2008
Month=`echo $Recent_Month_Hour | awk '{print $1}'`     # Nov
i=0
monthA=( "Jan" "Feb" "Mar" "Apr" "May" "Jun" "Jul" "Aug" "Sep" "Oct" "Nov" "Dec" )
monthN=( "01" "02" "03" "04" "05" "06" "07" "08" "09" "10" "11" "12" )
mm="00"
while true
do
	if [ "${monthA[i]}" = "${Month}" ]; then
		mm="${monthN[i]}"
		break
	fi
	i=$((i+1))
done
if [ "${Month}" = "Dec" -a "`date +%b`" = "Jan" -o "${Month}" = "Nov" -a "`date +%b`" = "Jan" ]; then
	# if Month of backup is December and today's month is Jan then yyyy-1
	yyyy=$((yyyy-1))
fi
dd=`echo $Recent_Month_Hour | awk '{print $2}'`        # 12
echo "${mm}/${dd}/${yyyy}"
}
#-----<--------->-------

LogPrint "NetBackup: restoring / into /mnt/local"

# $TMP_DIR/restore_fs_list was made by 30_create_nbu_restore_fs_list.sh

echo "change / to /mnt/local" >/tmp/nbu_change_file

FIRSTFS=( $( cat $TMP_DIR/restore_fs_list ) )
sdate=`Get_Start_Date ${FIRSTFS}`

if [ ${#NBU_ENDTIME[@]} -gt 0 ]
then
   edate="${NBU_ENDTIME[@]}"
   ARGS="-B -H -L /tmp/bplog.restore -8 -R /tmp/nbu_change_file -t 0 -w 0 -e ${edate} -C ${NBU_CLIENT_SOURCE} -D ${NBU_CLIENT_NAME} -f $TMP_DIR/restore_fs_list"
else
   ARGS="-B -H -L /tmp/bplog.restore -8 -R /tmp/nbu_change_file -t 0 -w 0 -s ${sdate} -C ${NBU_CLIENT_SOURCE} -D ${NBU_CLIENT_NAME} -f $TMP_DIR/restore_fs_list"
fi

LogPrint "RUN: /usr/openv/netbackup/bin/bprestore ${ARGS}"
LogPrint "Restore progress: see /tmp/bplog.restore"
LANG=C /usr/openv/netbackup/bin/bprestore ${ARGS}
if (( $? > 1 )); then
    Error "bprestore failed (return code = $?)"
fi
