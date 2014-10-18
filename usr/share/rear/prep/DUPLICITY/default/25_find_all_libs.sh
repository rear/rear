# This file is part of Relax and Recover, licensed under the GNU General
# Public License. Refer to the included LICENSE for full text of license.

# 25_find_all_libs.sh 
# This is to FInd Out Missing Librarys with Strace, if Strace isnt installed this is skipped

#Check if Strace Readlink File Is avabile and Backup_PROG=Duply 
which strace > /dev/null 2>&1
STRACE_OK=$?
which readlink > /dev/null 2>&1
READLINK_OK=$?
which file > /dev/null 2>&1
FILE_OK=$?
if [ "x$BACKUP_PROG" == "xduply" ] && [ $STRACE_OK -eq 0 ] && [ $READLINK_OK -eq 0 ] && [ $FILE_OK -eq 0 ]; then

# Find Out the File used by duply status
  FILES=`strace -Ff -e open duply $DUPLY_PROFILE status 2>&1 1>/dev/null|grep -v '= -1'|grep -i open|grep -v "open resumed" |cut -d \" -f 2|sort -u`

  for name in $FILES; do

	# Libs ar often Links, Solve the Links
	if [ -f $name ] || [ -L $name ]; then
		DATEI=`readlink -f $name`
		# Determinate if its a Lib
       		LIB=`file $DATEI|grep "shared object"|cut -d \: -f 1`
		#Determinate if its a Script
       		SKRIPT_FILES=`file $DATEI|grep "script,"|cut -d \: -f 1`
		# Add the Lib
		if [ "x$LIB" != "x" ]; then
          		LIBS=(
           			"${LIBS[@]}"
           			$name
          		)
       		fi
		#Add Script
       	if [ "x$SKRIPT_FILES" != "x" ]; then
	 		COPY_AS_IS=(
	   			"${COPY_AS_IS[@]}"
           			$SKRIPT_FILES
         		)
       		fi
     	fi 
   done
   # Filter if Duplicate Librarys have been added
   sorted_unique_LIBS=$(echo "${LIBS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
   eval LIBS=${sorted_unique_LIBS}[@]
   # Filter Duplicate Scripts
   sorted_unique_COPY_AS_IS=$(echo "${COPY_AS_IS[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')
   eval COPY_AS_IS=$sorted_unique_COPY_AS_IS
fi
