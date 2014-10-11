# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

# 25_find_all_libs.sh 
# This is to FInd Out Missing Librarys with Strace, if Strace isnt installed this is skipped

which strace > /dev/null 2>&1
if [ "x$BACKUP_PROG" == 'xduply' ] && [ $? -eq 0 ]; then

  FILES=`strace -Ff -e open duply $DUPLY_PROFILE status 2>&1 1>/dev/null|grep -v '= -1'|grep -i open|grep -v "open resumed" |cut -d \" -f 2|sort -u`
  for name in $FILES; do
     if [ -f $name ] || [ -L $name ]; then
       DATEI=`readlink -f $name`
       LIB=`file $DATEI|grep "shared object"|cut -d \: -f 1`
       if [ "x$LIB" != "x" ]; then
          LIBS=(
           "${LIBS[@]}"
           $LIB
          )
       fi
     fi 
   done
sorted_unique_LIBS=$(echo "${LIBS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
LIBS=$sorted_unique_LIBS
fi
