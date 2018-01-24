# global-functions.sh
#
# global functions for Relax-and-Recover
#
# This file is part of Relax-and-Recover, licensed under the GNU General
# Public License. Refer to the included COPYING for full text of license.

# Extract the real content from a config file provided as argument.
# It outputs non-empty and non-comment lines that do not start with a space.
# In other words it strips comments, empty lines, and lines with leading space(s):
function read_and_strip_file () {
    local filename="$1"
    test -s "$filename" || return 1
    sed -e '/^[[:space:]]/d;/^$/d;/^#/d' "$filename"
}

# Test if the (first) argument is an integer.
# If yes output the argument value and return 0
# otherwise output '0' and return 1:
function is_integer () {
    local argument="$1"
    if test "$argument" -eq "$argument" 2>/dev/null ; then
        # The arithmetic expansion removes a possible leading '+' in the output
        # so that e.g. "is_integer +12" outputs '12' (and not '+12')
        # and "is_integer -0" outputs '0' (and not '-0'):
        echo $(( argument + 0 ))
        return 0
    fi
    echo 0
    return 1
}

# Test if the (first) argument is a positive integer (i.e. test for '> 0')
# If yes output the argument value and return 0
# otherwise output '0' and return 1
# (in particular "is_positive_integer 0" outputs '0' but returns 1):
function is_positive_integer () {
    local argument="$1"
    if test "$argument" -gt 0 2>/dev/null ; then
        # The arithmetic expansion removes a possible leading '+' in the output
        # so that e.g. "is_positive_integer +12" outputs '12' (and not '+12'):
        echo $(( argument + 0 ))
        return 0
    fi
    echo 0
    return 1
}

# A function to test whether or not its arguments contain at least one 'real value'
# where 'real value' means to be neither empty nor only blank or control characters.
# The [:graph:] character class are the visible (a.k.a. printable) characters
# which is anything except spaces and control characters - i.e. the
# 7-bit ASCII codes from 0x21 up to 0x7E which are the following
# alphanumeric characters plus punctuation and symbol characters:
#  ! " # $ % & ' ( ) * + , - . / 0 1 2 3 4 5 6 7 8 9 : ; < = > ? @
#  A B C D E F G H I J K L M N O P Q R S T U V W X Y Z [ \ ] ^ _ `
#  a b c d e f g h i j k l m n o p q r s t u v w x y z { | } ~
# cf. http://www.regular-expressions.info/posixbrackets.html
function contains_visible_char () {
    # The outermost quotation "..." is dispensable in this particular case because
    # plain 'test' without an argument (i.e. with an empty argument) returns '1'
    # and here 'test' cannot get more than one argument ('test' for a string of
    # several non empty words returns '2' with 'bash: test: unary operator expected')
    # because 'tr' had removed all IFS characters so that 'test' gets at most one word:
    test "$( tr -d -c '[:graph:]' <<<"$*" )"
}

# Two explicit functions to be able to test explicitly for true and false (see issue #625)
# because "tertium non datur" (cf. https://en.wikipedia.org/wiki/Law_of_excluded_middle)
# does not hold for variables because variables could be unset or have empty value
# and to test if a variable is true or false its value is tested by that functions
# but the variable may not have a real value (i.e. be unset or have empty value) and
# because both functions test explicitly '! is_true' is not the same as 'is_false'
# and '! is_false' is not the same as 'is_true' (see both function comments below):

function is_true () {
    # The argument is usually the value of a variable which needs to be tested
    # only if there is explicitly a 'true' value then is_true returns true
    # so that an unset variable or an empty value is not true
    # and also for any other value that is not recognized as a 'true' value
    # by the is_true function the is_true function results false:
    case "$1" in
        ([tT] | [yY] | [yY][eE][sS] | [tT][rR][uU][eE] | 1)
        return 0 ;;
    esac
    return 1
}

function is_false () {
    # The argument is usually the value of a variable which needs to be tested
    # only if there is explicitly a 'false' value then is_false returns true
    # so that an unset variable or an empty value is not false
    # (caution: for unset or empty variables is_false is false)
    # and also for any other value that is not recognized as a 'false' value
    # by the is_false function the is_false function results false:
    case "$1" in
        ([fF] | [nN] | [nN][oO] | [fF][aA][lL][sS][eE] | 0)
        return 0 ;;
    esac
    return 1
}

# Two functions for percent-encoding and percent-decoding cf.
# https://en.wikipedia.org/wiki/Percent-encoding
# that are based on the urlencode and urldecode functions on
# https://askubuntu.com/questions/53770/how-can-i-encode-and-decode-percent-encoded-strings-on-the-command-line
#   urlencode() {
#       # urlencode <string>
#       local length="${#1}"
#       for (( i = 0; i < length; i++ )); do
#           local c="${1:i:1}"
#           case $c in
#               [a-zA-Z0-9.~_-]) printf "$c" ;;
#               *) printf '%%%02X' "'$c"
#           esac
#       done
#   }
#   urldecode() {
#       # urldecode <string>
#       local url_encoded="${1//+/ }"
#       printf '%b' "${url_encoded//%/\\x}"
#   }

function percent_encode() {
    # FIXME: the length could be wrong for UTF-8 encoded strings
    # at least on my <jsmeix@suse.de> SLES11-SP4 system with GNU bash version 3.2.57
    # like the UTF-8 encoded German word bin[a_umlaut]r
    # cf. https://en.opensuse.org/SDB:Plain_Text_versus_Locale
    #
    #   export LANG=C ; export LC_ALL=C
    #
    #   string="$( echo -en "bin\0303\0244r" )"
    #
    #   echo -n $string | od -c
    #   0000000   b   i   n 303 244   r
    #   0000006
    #
    #   length="${#string}"
    #
    #   echo $length
    #   5
    #
    # In general the current percent_encode function fails for UTF-8 encoded strings
    #   percent_encode "$( echo -en "bin\0303\0244r" )"
    #   bin%FFFFFFFFFFFFFFC3r
    # and running that with 'set -x' shows the UTF-8 encoded bytes cause it:
    #   + char=$'\303\244'
    #   + case $char in
    #   + printf %%%02X ''\''Ã#'
    #   %FFFFFFFFFFFFFFC3+
    # because the '\303\244' UTF-8 bytes should get encoded byte by byte
    # but not as two bytes at the same time so that the problem is
    # how to process a string single byte by single byte in bash.
    # Perhaps this is a bug in GNU bash version 3.2.57 because
    #
    #   export LANG=C ; export LC_ALL=C
    #
    #   char=$'\303\244'
    #
    #   echo -n $char | od -c
    #   0000000 303 244
    #   0000002
    #
    #   clength="${#char}"
    #
    #   # echo $clength
    #   1
    #
    # Again (as above) it seems GNU bash version 3.2.57 results a wrong length
    # which seems to be the root cause why percent_encode() fails for UTF-8 encoded strings.
    local string="$*"
    local length="${#string}"
    local pos=0
    local char=""
    for (( pos = 0 ; pos < length ; pos++ )) ; do
        char="${string:pos:1}"
        case $char in
            # Unreserved characters are a-z A-Z 0-9 . ~ _ - which are not percent-encoded because
            # for maximum interoperability producers are discouraged from percent-encoding unreserved characters
            # see https://en.wikipedia.org/wiki/Percent-encoding
            ([a-zA-Z0-9.~_-])
                printf "$char"
                ;;
            # All non-unreserved characters get percent-encoded:
            (*)
                # A literal single-quote in front of a character is interpreted as the character's number
                # according to the underlying locale setting so that
                #   printf "%X" "'k"
                # outputs the hexadecimal number of the k character which is 6B
                printf '%%%02X' "'$char"
                ;;
        esac
    done
}

function percent_decode() {
    # The special handling for '+' characters in a percent-encoded string in the above urldecode function
    # is not implemented here because I <jsmeix@suse.de> think that case does not happen in ReaR because
    # the percent_encode function encodes a '+' character in the original string as '%2B'
    # so that a literal '+' character in a percent-encoded string should not happen.
    local string="$*"
    # Convert the percent-encoded string into a backslash-escape hexadecimal encoded string:
    local backslash_escape_encoded="${string//%/\\x}"
    # Print the backslash-escape encoded string while interpreting backslash escapes in there:
    printf '%b' "$backslash_escape_encoded"
}

######
### Functions for dealing with URLs
######
# URL is the most common form of URI
# see https://en.wikipedia.org/wiki/Uniform_Resource_Identifier
# where a generic URI is of the form
# scheme:[//[user:password@]host[:port]][/]path[?query][#fragment]
# e.g. for BACKUP_URL=sshfs://user@host/G/rear/
# url_scheme = 'sshfs' , url_host = 'user@host' , url_hostname = 'host' , url_username = 'user' , url_path = '/G/rear/'
# e.g. for BACKUP_URL=usb:///dev/sdb1
# url_scheme = 'usb' , url_host = '' , url_hostname = '' , url_username = '' , url_path = '/dev/sdb1'
# FIXME: the ulr_* functions are not safe against special characters
# for example they break when the password contains spaces
# but on the other hand permitted characters for values in a URI
# are ASCII letters, digits, dot, hyphen, underscore, and tilde
# and any other character must be percent-encoded (in particular the
# characters : / ? # [ ] @ are reserved as delimiters of URI components
# and must be percent-encoded when used in the value of a URI component)
# so that what is missing is support for percent-encoded characters
# but user-friendly support for percent-encoded characters is not possible
# cf. http://bugzilla.opensuse.org/show_bug.cgi?id=561626#c7

function url_scheme() {
    local url=$1
    # the scheme is the leading part up to '://'
    local scheme=${url%%://*}
    # rsync scheme does not have to start with rsync:// it can also be scp style
    # see the comments in usr/share/rear/prep/RSYNC/default/100_check_rsync.sh
    echo $scheme | grep -q ":" && echo rsync || echo $scheme
}

function url_host() {
    local url=$1
    local url_without_scheme=${url#*//}
    # the authority part is the part after the scheme (e.g. 'host' or 'user@host')
    # i.e. after 'scheme://' all up to but excluding the next '/'
    # which means it breaks if there is a username that contains a '/'
    # which should not happen because a POSIX-compliant username
    # should have only characters from the portable filename character set
    # which is ASCII letters, digits, dot, hyphen, and underscore
    # (a hostname must not contain a '/' see RFC 952 and RFC 1123)
    local authority_part=${url_without_scheme%%/*}
    # for backward compatibility the url_host function returns the whole authority part
    # see https://github.com/rear/rear/issues/856
    # to get only hostname or username use the url_hostname and url_username functions
    echo $authority_part
}

function url_hostname() {
    local url=$1
    local url_without_scheme=${url#*//}
    local authority_part=${url_without_scheme%%/*}
    # if authority_part contains a '@' we assume the 'user@host' format and
    # then we remove the 'user@' part (i.e. all up to and including the last '@')
    # so that it also works when the username contains a '@'
    # like 'john@doe' in BACKUP_URL=sshfs://john@doe@host/G/rear/
    # (a hostname must not contain a '@' see RFC 952 and RFC 1123)
    local host_and_port=${authority_part##*@}
    # if host_and_port contains a ':' we assume the 'host:port' format and
    # then we remove the ':port' part (i.e. all from and including the last ':')
    # so that it even works when the hostname contains a ':' (in spite of RFC 952 and RFC 1123)
    echo ${host_and_port%:*}
}

function url_username() {
    local url=$1
    local url_without_scheme=${url#*//}
    local authority_part=${url_without_scheme%%/*}
    # authority_part must contain a '@' when a username is specified
    echo $authority_part | grep -q '@' || return 0
    # we remove the '@host' part (i.e. all from and including the last '@')
    # so that it also works when the username contains a '@'
    # like 'john@doe' in BACKUP_URL=sshfs://john@doe@host/G/rear/
    # (a hostname must not contain a '@' see RFC 952 and RFC 1123)
    local user_and_password=${authority_part%@*}
    # if user_and_password contains a ':' we assume the 'user:password' format and
    # then we remove the ':password' part (i.e. all from and including the first ':')
    # so that it works when the password contains a ':'
    # (a POSIX-compliant username should not contain a ':')
    echo $user_and_password | grep -q ':' && echo ${user_and_password%%:*} || echo $user_and_password
}

function url_password() {
    local url=$1
    local url_without_scheme=${url#*//}
    local authority_part=${url_without_scheme%%/*}
    # authority_part must contain a '@' when a username is specified
    echo $authority_part | grep -q '@' || return 0
    # we remove the '@host' part (i.e. all from and including the last '@')
    # so that it also works when the username contains a '@'
    # like 'john@doe' in BACKUP_URL=sshfs://john@doe@host/G/rear/
    # (a hostname must not contain a '@' see RFC 952 and RFC 1123)
    local user_and_password=${authority_part%@*}
    # user_and_password must contain a ':' when a password is specified
    echo $user_and_password | grep -q ':' || return 0
    # we remove the 'user:' part (i.e. all up to and including the first ':')
    # so that it works when the password contains a ':'
    # (a POSIX-compliant username should not contain a ':')
    echo ${user_and_password#*:}
}

function url_path() {
    local url=$1
    local url_without_scheme=${url#*//}
    # the path is all from and including the first '/' in url_without_scheme
    # i.e. the whole rest after the authority part so that
    # it may contain an optional trailing '?query' and '#fragment'
    echo /${url_without_scheme#*/}
}

backup_path() {
    local scheme=$1
    local path=$2
    case $scheme in
       (tape)  # no path for tape required
           path=""
           ;;
       (file)  # type file needs a local path (must be mounted by user)
           path="$path/${NETFS_PREFIX}"
           ;;
       (iso)
           if [[ "$WORKFLOW" = "recover" ]]; then
               # The backup is located inside the ISO mount point when we do a recover
               path="${BUILD_DIR}/outputfs${path}"
           else
               # The backup will be located on the ISO temporary dir
               path="${TMP_DIR}/isofs${path}"
           fi
           ;;
       (*)     # nfs, cifs, usb, a.o. need a temporary mount-path
           path="${BUILD_DIR}/outputfs/${NETFS_PREFIX}"
           ;;
    esac
    echo "$path"
}

output_path() {
    local scheme=$1
    local path=$2
    case $scheme in
       (null|tape)  # no path for tape required
           path=""
           ;;
       (file)  # type file needs a local path (must be mounted by user)
           path="$path/${OUTPUT_PREFIX}"
           ;;
       (*)     # nfs, cifs, usb, a.o. need a temporary mount-path
           path="${BUILD_DIR}/outputfs/${OUTPUT_PREFIX}"
           ;;
    esac
    echo "$path"
}


### Mount URL $1 at mountpoint $2[, with options $3]
mount_url() {
    local url=$1
    local mountpoint=$2
    local defaultoptions="rw,noatime"
    local options=${3:-"$defaultoptions"}

    ### Generate a mount command
    local mount_cmd
    case $(url_scheme $url) in
        (null|tape|file|rsync|fish|ftp|ftps|hftp|http|https|sftp)
            ### Don't need to mount anything for these
            return 0
            ;;
        (iso)
            if [[ "$WORKFLOW" = "recover" ]]; then
                mount_cmd="mount /dev/disk/by-label/${ISO_VOLID} $mountpoint"
            else
                return 0
            fi
            ;;
        (var)
            ### The mount command is given by variable in the url host
            local var=$(url_host $url)
            mount_cmd="${!var} $mountpoint"
            ;;
        (cifs)
            if [ x"$options" = x"$defaultoptions" ];then
                # defaultoptions contains noatime which is not valid for cifs (issue #752)
                mount_cmd="mount $v -o rw,guest //$(url_host $url)$(url_path $url) $mountpoint"
            else
                mount_cmd="mount $v -o $options //$(url_host $url)$(url_path $url) $mountpoint"
            fi
            ;;
        (usb)
            mount_cmd="mount $v -o $options $(url_path $url) $mountpoint"
            ;;
        (sshfs)
            local authority=$( url_host $url )
            test "$authority" || Error "Cannot run 'sshfs' because no authority '[user@]host' found in URL '$url'."
            local path=$( url_path $url )
            test "$path" || Error "Cannot run 'sshfs' because no path found in URL '$url'."
            # ensure the fuse kernel module is loaded because sshfs is based on FUSE
            lsmod | grep -q '^fuse' || modprobe $verbose fuse || Error "Cannot run 'sshfs' because 'fuse' kernel module is not loadable."
            mount_cmd="sshfs $authority:$path $mountpoint -o $options"
            ;;
        (ftpfs)
            local hostname=$( url_hostname $url )
            test "$hostname" || Error "Cannot run 'curlftpfs' because no hostname found in URL '$url'."
            local path=$( url_path $url )
            test "$path" || Error "Cannot run 'curlftpfs' because no path found in URL '$url'."
            local username=$( url_username $url )
            # ensure the fuse kernel module is loaded because ftpfs (via CurlFtpFS) is based on FUSE
            lsmod | grep -q '^fuse' || modprobe $verbose fuse || Error "Cannot run 'curlftpfs' because 'fuse' kernel module is not loadable."
            if test "$username" ; then
                local password=$( url_password $url )
                if test "$password" ; then
                    # single quoting is a must for the password
                    mount_cmd="curlftpfs $verbose -o user='$username:$password' ftp://$hostname$path $mountpoint"
                else
                    # also single quoting for the plain username so that it also works for non-POSIX-compliant usernames
                    # (a POSIX-compliant username should only contain ASCII letters, digits, dot, hyphen, and underscore)
                    mount_cmd="curlftpfs $verbose -o user='$username' ftp://$hostname$path $mountpoint"
                fi
            else
                mount_cmd="curlftpfs $verbose ftp://$hostname$path $mountpoint"
            fi
            ;;
        (davfs)
            mount_cmd="mount $v -t davfs http://$(url_host $url)$(url_path $url) $mountpoint"
            ;;
        (*)
            mount_cmd="mount $v -t $(url_scheme $url) -o $options $(url_host $url):$(url_path $url) $mountpoint"
            ;;
    esac

    Log "Mounting with '$mount_cmd'"
    # eval is required when mount_cmd contains single quoted stuff (e.g. see the above mount_cmd for curlftpfs)
    eval $mount_cmd >&2
    StopIfError "Mount command '$mount_cmd' failed."

    AddExitTask "umount -f $v '$mountpoint' >&2"
    return 0
}

### Unmount url $1 at mountpoint $2
umount_url() {
    local url=$1
    local mountpoint=$2

    case $(url_scheme $url) in
        (null|tape|file|rsync|fish|ftp|ftps|hftp|http|https|sftp)
            ### Don't need to umount anything for these
            return 0
            ;;
        (iso)
            if [[ "$WORKFLOW" != "recover" ]]; then
                return 0
            fi
            ;;
	    (sshfs)
	        umount_cmd="fusermount -u $mountpoint"
	    ;;
	    (davfs)
	        umount_cmd="umount $mountpoint"
            # Wait for 3 sek. then remove the cache-dir /var/cache/davfs
            sleep 30
            # ToDo: put in here the cache-dir from /etc/davfs2/davfs.conf
            # and delete only the just used cache
            #rm -rf /var/cache/davfs2/*<mountpoint-hash>*
            rm -rf /var/cache/davfs2/*outputfs*

	    ;;
        (var)
            local var=$(url_host $url)
            umount_cmd="${!var} $mountpoint"

            Log "Unmounting with '$umount_cmd'"
            $umount_cmd
            StopIfError "Unmounting failed."

            RemoveExitTask "umount -f $v '$mountpoint' >&2"
            return 0
            ;;
    esac

    umount_mountpoint $mountpoint
    StopIfError "Unmounting '$mountpoint' failed."

    RemoveExitTask "umount -f $v '$mountpoint' >&2"
    return 0
}

### Unmount mountpoint $1
umount_mountpoint() {
    local mountpoint=$1

    ### First, try a normal unmount,
    Log "Unmounting '$mountpoint'"
    umount $v $mountpoint >&2
    if [[ $? -eq 0 ]] ; then
        return 0
    fi

    ### otherwise, try to kill all processes that opened files on the mount.
    # TODO: actually implement this

    ### If that still fails, force unmount.
    Log "Forced unmount of '$mountpoint'"
    umount $v -f $mountpoint >&2
    if [[ $? -eq 0 ]] ; then
        return 0
    fi

    Log "Unmounting '$mountpoint' failed."
    return 1
}

# Change $1 to user input or leave default value on empty input
function change_default
{
    local response
    # Use the original STDIN STDOUT and STDERR when 'rear' was launched by the user
    # because 'read' outputs non-error stuff also to STDERR (e.g. its prompt):
    read response 0<&6 1>&7 2>&8

    if [ -n "$response" ]; then
        eval $1=\$response
    fi
}

# Check if block device is mounted
# lsblk can discover mounted device even if mounted as link, this makes it
# more suitable for job then e.g. grep from /proc/mounts
function is_device_mounted
{
   disk=$1
   [ -z "$disk" ] && echo 1

   m=$(lsblk -n -o MOUNTPOINT $disk 2> /dev/null)

   if [ -z $m ]; then
      echo 0
   else
      echo 1
   fi
}

# Use 'bc' for calculations because other tools
# fail in various unexpected ways for big numbers,
# c.f. https://github.com/rear/rear/issues/1307
# The idea of the mathlib_calculate () is to do all
# calculations with basically unlimited precision
# and only have the final result as integer.
# Therefore one cannot use the mathlib_calculate ()
# to get an integer remainder (modulo).
#
# e.g.
# With bash arithmetic expansion
#   # start=123456
#   # echo $(( $start % 4096 ))
#   # 576
#
# But will fail with mathlib_calculate ()
#   # mathlib_calculate "$start % 4096"
#   # 0
#
function mathlib_calculate()
{
    bc -ql <<<"result=$@ ; scale=0 ; result / 1 "
}

# Purpose is to find a working DUPLY profile configuration
# Duply is a wrapper script around duplicity - this function is
# used in the prep phase (for mkbackup) and in the verify phase
# (to check the TEMP_DIR directory - it must be defined and cannot
# be /tmp as this is usally a tmpfs file system which is too small)
function find_duply_profile ()
{
    # there could be more then one profile present - select where SOURCE='/'
    for CONF in $(echo "$1")
    do
        [[ ! -f $CONF ]] && continue
        source $CONF    # is a normal shell configuration file
        LogIfError "Could not source $CONF [duply profile]"
        [[ -z "$SOURCE" ]] && continue
        [[ -z "$TARGET" ]] && continue
        # still here?
        if [[ "$SOURCE" = "/" ]]; then
            DUPLY_PROFILE_FILE=$CONF
            DUPLY_PROFILE=$( dirname $CONF  )   # /root/.duply/mycloud/conf -> /root/.duply/mycloud
            DUPLY_PROFILE=${DUPLY_PROFILE##*/}  # /root/.duply/mycloud      -> mycloud
            break # the loop
        else
            DUPLY_PROFILE=""
            continue
        fi
    done
}

