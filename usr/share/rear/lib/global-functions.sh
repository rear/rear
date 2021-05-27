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

# Three functions to test
#   if the argument is an integer
#   if the argument is a positive integer (i.e. test for '> 0')
#   if the argument is a nonnegative integer (i.e. test for '>= 0')
# where the argument is limted by the bash integer arithmetic range limitation
# from - ( 2^63 ) = -9223372036854775808 to 9223372036854775807 = + ( 2^63 - 1 )
# e.g. "is_nonnegative_integer 9223372036854775807" works (tested down to SLES11 on 32-bit x86)
# but "is_nonnegative_integer 9223372036854775808" is out of range and returns a wrong result, cf.
# https://github.com/rear/rear/issues/1269#issuecomment-290006467

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

# Test if the (first) argument is a nonnegative integer (i.e. test for '>= 0')
# If yes output the argument value and return 0
# otherwise output '0' and return 1
# (in particular "is_nonnegative_integer -00" outputs '0' and returns 0):
function is_nonnegative_integer () {
    local argument="$1"
    if test "$argument" -ge 0 2>/dev/null ; then
        # The arithmetic expansion removes a possible leading '+' in the output
        # so that e.g. "is_nonnegative_integer +12" outputs '12' (and not '+12')
        # and "is_nonnegative_integer -0" outputs '0' (and not '-0'):
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
    #   + printf %%%02X ''\''A#'
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

### Returns true if one can upload files to the URL
function scheme_accepts_files() {
    local scheme=$1
    case $scheme in
        (null|tape|obdr)
            # tapes do not support uploading arbitrary files, one has to handle them
            # as special case (usually passing the tape device as argument to tar)
            # null means do not upload anything anywhere, leave the files under /var/lib/rear/output
            return 1
            ;;
        (*)
            # most URL schemes support uploading files
            return 0
            ;;
    esac
}

### Returns true if URLs with the given scheme corresponds to a path inside
### a mountable fileystem and one can put files directly into it.
### The actual path will be returned by backup_path() / output_path().
### If returns false, using backup_path() / output_path() has no sense
### and one must use a scheme-specific method (like lftp or writing them to a tape)
### to upload files to the destination instead of just "cp" or other direct filesystem access.
### Returning true does not imply that the URL is currently mounted at a filesystem and usable,
### only that it can be mounted (use mount_url() first)
function scheme_supports_filesystem() {
    local scheme=$1
    case $scheme in
        (null|tape|obdr|rsync|fish|ftp|ftps|hftp|http|https|sftp)
            return 1
            ;;
        (*)
            return 0
            ;;
    esac
}

function backup_path() {
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

function output_path() {
    local scheme=$1
    local path=$2

    # Abort for unmountable schemes ("tape-like" or "ftp-like" schemes).
    # Returning an empty string for them is not satisfactory: it could lead to caller putting its files
    # under / instead of the intended location if the result is not checked for emptiness.
    # Returning ${BUILD_DIR}/outputfs/${OUTPUT_PREFIX} for unmountable URLs is also not satisfactory:
    # caller could put its files there expecting them to be safely at their destination,
    # but if the directory is not a mountpoint, they would get silently lost.
    # The caller needs to check the URL/scheme using scheme_supports_filesystem()
    # before calling this function.
    scheme_supports_filesystem $scheme || BugError "output_path() called with scheme $scheme that does not support filesystem access"

    case $scheme in
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
function mount_url() {
    local url=$1
    local mountpoint=$2
    local defaultoptions="rw,noatime"
    local options=${3:-"$defaultoptions"}
    local scheme

    scheme=$( url_scheme $url )

    # The cases where we return 0 are those that do not need umount and also do not need ExitTask handling.
    # They thus need to be kept in sync with umount_url() so that RemoveExitTasks is used
    # iff AddExitTask was used in mount_url().

    if ! scheme_supports_filesystem $scheme ; then
        ### Stuff like null|tape|rsync|fish|ftp|ftps|hftp|http|https|sftp
        ### Don't need to umount anything for these.
        ### file: supports filesystem access, but is not mounted and unmounted,
        ### so it has to be handled specially below.
        ### Similarly for iso: which gets mounted and unmounted only during recovery.
        return 0
    fi

    ### Generate a mount command
    local mount_cmd
    case $scheme in
        (file)
            ### Don't need to mount anything for file:, it is already mounted by user
            return 0
            ;;
        (iso)
            # Check that there is a symbolic link /dev/disk/by-label/RELAXRECOVER
            # that points to a block device that uses the filesystem label RELAXRECOVER.
            # RELAXRECOVER is the default value of the ISO_VOLID config variable.
            # If no such symbolic link exists create one because it is needed
            # during "rear recover" when the ISO image contains the backup,
            # see https://github.com/rear/rear/issues/1893
            # and https://github.com/rear/rear/issues/1891
            # and https://github.com/rear/rear/issues/326
            # so that there is nothing to do here unless during "rear recover":
            test "recover" = "$WORKFLOW" || return 0
            # Try to find a block device that uses the filesystem label ISO_VOLID.
            # Usually "blkid -L RELAXRECOVER" results '/dev/sr0' or '/dev/sr1'
            # cf. https://github.com/rear/rear/issues/1893#issuecomment-411034001
            # but "blkid -L" is not supported on SLES10 (blkid is too old there)
            # so that the traditional form "blkid -l -o device -t LABEL=RELAXRECOVER"
            # is used which also works and is described in "man blkid" on SLES15:
            local relaxrecover_block_device="$( blkid -l -o device -t LABEL="$ISO_VOLID" )"
            # Try to get where the symbolic link /dev/disk/by-label/ISO_VOLID points to.
            # "readlink -e symlink" outputs nothing when the symlink or its target does not exist:
            local relaxrecover_symlink_name="/dev/disk/by-label/$ISO_VOLID"
            local relaxrecover_symlink_target="$( readlink $verbose -e "$relaxrecover_symlink_name" )"
            # Everything is o.k. when relaxrecover_block_device and relaxrecover_symlink_target are non-empty
            # and when the relaxrecover_symlink_target value is the relaxrecover_block_device value.
            # Usually the right symbolic link /dev/disk/by-label/ISO_VOLID is set up automatically by udev.
            if ! test "$relaxrecover_block_device" -a "$relaxrecover_symlink_target" -a "$relaxrecover_symlink_target" = "$relaxrecover_block_device" ; then
                # If not everything is o.k. first try fix things automatically:
                Log "Symlink '$relaxrecover_symlink_name' does not exist or does not point to a block device with '$ISO_VOLID' filesystem label"
                # One of the things that could be not o.k. is that there is no /dev/disk/by-label/ directory.
                # Usually udev would automatically create it but sometimes that does not work,
                # cf. https://github.com/rear/rear/issues/1891#issuecomment-411027324
                # so that we create a /dev/disk/by-label/ directory if it is not there:
                mkdir $verbose -p /dev/disk/by-label
                # Try to let the symbolic link point to the block device that uses the filesystem label ISO_VOLID:
                if test -b "$relaxrecover_block_device" ; then
                    Log "Making symlink '$relaxrecover_symlink_name' point to '$relaxrecover_block_device' because it has filesystem label '$ISO_VOLID'"
                    # Below there is a test that /dev/disk/by-label/ISO_VOLID exists which should detect when this 'ln' command failed:
                    ln $verbose -sf "$relaxrecover_block_device" "$relaxrecover_symlink_name"
                else
                    # We found no block device that uses the filesystem label ISO_VOLID:
                    Log "No block device with ISO filesystem label '$ISO_VOLID' found (by the blkid command)"
                    # At this point things look not good so that now we need to tell the user about what is wrong:
                    LogPrintError "A symlink '$relaxrecover_symlink_name' is required that points to the device with the ReaR ISO image"
                    rear_workflow="rear $WORKFLOW"
                    rear_shell_history="$( echo -e "ln -vsf /dev/cdrom $relaxrecover_symlink_name\nls -l $relaxrecover_symlink_name" )"
                    unset choices
                    choices[0]="/dev/cdrom is where the ISO is attached to"
                    choices[1]="/dev/sr0 is where the ISO is attached to"
                    choices[2]="/dev/sr1 is where the ISO is attached to"
                    choices[3]="Use Relax-and-Recover shell and return back to here"
                    choices[4]="Continue '$rear_workflow'"
                    choices[5]="Abort '$rear_workflow'"
                    prompt="Create symlink '$relaxrecover_symlink_name' that points to the ReaR ISO image device"
                    choice=""
                    wilful_input=""
                    symlink_target=""
                    # When USER_INPUT_RELAXRECOVER_SYMLINK_TARGET has any 'true' value be liberal in what you accept and
                    # assume choices[0] 'Let /dev/disk/by-label/RELAXRECOVER point to /dev/cdrom' was actually meant:
                    is_true "$USER_INPUT_RELAXRECOVER_SYMLINK_TARGET" && USER_INPUT_RELAXRECOVER_SYMLINK_TARGET="${choices[0]}"
                    while true ; do
                        choice="$( UserInput -I RELAXRECOVER_SYMLINK_TARGET -p "$prompt" -D "${choices[0]}" "${choices[@]}" )" && wilful_input="yes" || wilful_input="no"
                        case "$choice" in
                            (${choices[0]})
                                symlink_target="/dev/cdrom"
                                is_true "$wilful_input" && LogPrint "User confirmed symlink target $symlink_target" || LogPrint "Using symlink target $symlink_target by default"
                                # Below there is a test that /dev/disk/by-label/ISO_VOLID exists which should detect when this 'ln' command failed:
                                ln $verbose -sf $symlink_target "$relaxrecover_symlink_name"
                                break
                                ;;
                            (${choices[1]})
                                symlink_target="/dev/sr0"
                                LogPrint "Using symlink target $symlink_target"
                                # Below there is a test that /dev/disk/by-label/ISO_VOLID exists which should detect when this 'ln' command failed:
                                ln $verbose -sf $symlink_target "$relaxrecover_symlink_name"
                                break
                                ;;
                            (${choices[2]})
                                symlink_target="/dev/sr1"
                                LogPrint "Using symlink target $symlink_target"
                                # Below there is a test that /dev/disk/by-label/ISO_VOLID exists which should detect when this 'ln' command failed:
                                ln $verbose -sf $symlink_target "$relaxrecover_symlink_name"
                                break
                                ;;
                            (${choices[3]})
                                # rear_shell runs 'bash' with the original STDIN STDOUT and STDERR when 'rear' was launched by the user:
                                rear_shell "" "$rear_shell_history"
                                ;;
                            (${choices[4]})
                                LogPrint "User chose to continue '$rear_workflow'"
                                break
                                ;;
                            (${choices[5]})
                                abort_recreate
                                Error "User chose to abort '$rear_workflow' in ${BASH_SOURCE[0]}"
                                ;;
                        esac
                    done
                fi
            fi
            # Check if /dev/disk/by-label/$ISO_VOLID exists (as symbolic link or in any other form), if yes assume things are right:
            test -e "$relaxrecover_symlink_name" || Error "Cannot mount ISO because there is no '$relaxrecover_symlink_name'"
            mount_cmd="mount $relaxrecover_symlink_name $mountpoint"
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

    # create mount point
    mkdir -p $v "$mountpoint" >&2 || Error "Could not mkdir '$mountpoint'"
    AddExitTask "remove_temporary_mountpoint '$mountpoint'"

    Log "Mounting with '$mount_cmd'"
    # eval is required when mount_cmd contains single quoted stuff (e.g. see the above mount_cmd for curlftpfs)
    eval $mount_cmd || Error "Mount command '$mount_cmd' failed."

    AddExitTask "umount -f $v '$mountpoint' >&2"
    return 0
}

function remove_temporary_mountpoint() {
    rmdir $v "$1" >&2
}

### Unmount url $1 at mountpoint $2, perform mountpoint cleanup and exit task + error handling
function umount_url() {
    local url=$1
    local mountpoint=$2
    local scheme

    scheme=$( url_scheme $url )

    # The cases where we return 0 are those that do not need umount and also do not need ExitTask handling.
    # They thus need to be kept in sync with mount_url() so that RemoveExitTasks is used
    # iff AddExitTask was used in mount_url().

    if ! scheme_supports_filesystem $scheme ; then
        ### Stuff like null|tape|rsync|fish|ftp|ftps|hftp|http|https|sftp
        ### Don't need to umount anything for these.
        ### file: supports filesystem access, but is not mounted and unmounted,
        ### so it has to be handled specially below.
        ### Similarly for iso: which gets mounted and unmounted only during recovery.
        return 0
    fi

    case $scheme in
        (file)
            return 0
            ;;
        (iso)
            if [[ "$WORKFLOW" != "recover" ]]; then
                return 0
            fi
            ;;
        (*)
            # Schemes that actually need nontrivial umount are handled below.
            # We do not handle them in the default branch because in the case of iso:
            # it depends on the current workflow whether umount is needed or not.
            :
    esac

    # umount_url() is a wrapper that takes care of exit tasks and error handling and mountpoint cleanup.
    # Therefore it also determines if exit task and mountpoint handling is required and returns early if not.
    # The actual umount job is performed inside perform_umount_url().
    # We do not request lazy umount here because we want umount errors to be reliably reported.
    perform_umount_url $url $mountpoint || Error "Unmounting '$mountpoint' failed."

    RemoveExitTask "umount -f $v '$mountpoint' >&2"

    remove_temporary_mountpoint '$mountpoint' && RemoveExitTask "remove_temporary_mountpoint '$mountpoint'"
    return 0
}

### Unmount url $1 at mountpoint $2 [ lazily if $3 is set and normal unmount fails ]
function perform_umount_url() {
    local url=$1
    local mountpoint=$2
    local lazy=${3:-}

    case $(url_scheme $url) in
        (sshfs)
            fusermount -u ${lazy:+'-z'} $mountpoint
            ;;
        (davfs)
            umount_davfs $mountpoint $lazy
            ;;
        (var)
            local var
            var=$(url_host $url)
            Log "Unmounting with '${!var} $mountpoint'"
            # lazy unmount not supported with custom umount command
            ${!var} $mountpoint
            ;;
        (*)
            # usual umount command
            umount_mountpoint $mountpoint $lazy
    esac
    # The switch above must be the last statement in this function and the umount commands must be
    # the last commands (or part of) in each branch. This ensures proper exit code propagation
    # to the caller even when set -e is used.
}

### Helper which unmounts davfs mountpoint $1 and cleans up the cache,
### performing lazy unmount if $2 is nonempty and normal unmount fails.
function umount_davfs() {
    local mountpoint=$1
    local lazy="${2:-}"
    if umount_mountpoint $mountpoint ; then
        # Wait for 3 sek. then remove the cache-dir /var/cache/davfs
        sleep 30
        # TODO: put in here the cache-dir from /etc/davfs2/davfs.conf
        # and delete only the just used cache
        #rm -rf /var/cache/davfs2/*<mountpoint-hash>*
        rm -rf /var/cache/davfs2/*outputfs*
    else
        local retval=$?

        if test $lazy ; then
            # try again to unmount lazily and this time do not delete the cache, it is still in use.
            LogPrintError "davfs cache /var/cache/davfs2/*outputfs* needs to be cleaned up manually after the lazy unmount finishes"
            umount_mountpoint_lazy $mountpoint
        else
            # propagate errors from umount
            return $retval
        fi
    fi
}

### Unmount mountpoint $1 [ lazily if $2 is nonempty ]
### Default implementation for filesystems that don't need anything fancy
### For special umount commands use perform_umount_url()
function umount_mountpoint() {
    local mountpoint=$1
    local lazy=${2:-}

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

    if test $lazy ; then
        umount_mountpoint_lazy $mountpoint
    else
        return 1
    fi
}

### Unmount mountpoint $1 lazily
### Preferably use "umount_mountpoint $mountpoint y", which attempts non-lazy unmount first.
function umount_mountpoint_lazy() {
    local mountpoint=$1

    LogPrint "Directory $mountpoint still mounted - trying lazy umount"
    umount $v -f -l $mountpoint >&2
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
function is_device_mounted()
{
   local disk=$1
   [ -z "$disk" ] && echo 0 && return

   local m=$(lsblk -n -o MOUNTPOINT $disk 2> /dev/null)

   if [ -z $m ]; then
      echo 0
   else
      echo 1
   fi
}

# Return mountpoint if block device is mounted
# (based on 'is_device_mounted()' above)
function get_mountpoint()
{
   local disk=$1
   [ -z "$disk" ] && return 1

   local mp=$(lsblk -n -o MOUNTPOINT $disk 2> /dev/null)

   echo $mp
}

# Returns the appropriate command to execute in order
# to re-mount the given mountpoint
function build_remount_cmd()
{
   local mp=$1
   [ -z "$mp" ] && return 1
  
   local -a allopts=()
   # Get: device, mountpoint, FS type, mount options as string
   local opt_string=$(mount | grep " $mp " | awk '{ print $1 " " $3 " " $5 " " $6 }')
   [ -z "$opt_string" ] && return 1

   # Split string, store in array
   for opt in $opt_string; do
      allopts+=( "$opt" )
   done
   # Remove parentheses around mount options
   allopts[3]=${allopts[3]##(}
   allopts[3]=${allopts[3]%%)}

   # return mount command as result
   echo "mount $v -t ${allopts[2]} -o ${allopts[3]} ${allopts[0]} ${allopts[1]}"
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

