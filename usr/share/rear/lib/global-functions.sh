# global-functions.sh
#
# global functions for Relax-and-Recover
#
#    Relax-and-Recover is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.

#    Relax-and-Recover is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with Relax-and-Recover; if not, write to the Free Software
#    Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
#

function read_and_strip_file () {
# extracts content from config files. In other words: strips the comments and new lines
    if test -s "$1" ; then
        sed -e '/^[[:space:]]/d;/^$/d;/^#/d' "$1"
    fi
}

function is_numeric () {
    # simple test if var is an integer
    if expr $1 + 0 >/dev/null 2>&1 ; then
        echo $1
    else
        echo 0
    fi
}

# two explicit functions to be able to test explicitly for true and false (see issue #625)
# because "tertium non datur" (cf. https://en.wikipedia.org/wiki/Law_of_excluded_middle)
# does not hold for variables because variables could be unset or have empty value
# and to test if a variable is true or false its value is tested by that functions
# but the variable may not have a real value (i.e. be unset or have empty value):

function is_true () {
    # the argument is usually the value of a variable which needs to be tested
    # only if there is explicitly a 'true' value then is_true returns true
    # so that an unset variable or an empty value is not true:
    case "$1" in
        ([tT] | [yY] | [yY][eE][sS] | [tT][rR][uU][eE] | 1)
        return 0 ;;
    esac
    return 1
}

function is_false () {
    # the argument is usually the value of a variable which needs to be tested
    # only if there is explicitly a 'false' value then is_false returns true
    # so that an unset variable or an empty value is not false
    # caution: for unset or empty variables is_false is false
    case "$1" in
        ([fF] | [nN] | [nN][oO] | [fF][aA][lL][sS][eE] | 0)
        return 0 ;;
    esac
    return 1
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
    # see the comments in usr/share/rear/prep/RSYNC/default/10_check_rsync.sh
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

