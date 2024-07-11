#
# Optionally relabel an SELinux-protected system
#

# FIXME: The following test looks somewhat oversophisticated:
# It only evaluates to 'true' if grep outputs exactly one (non-empty) word
# (in this case that word is 'SELINUX=enforcing') because otherwise
# e.g. "test a b" fails with "bash: [: a: unary operator expected"
# and e.g. "test a b c d" fails with "bash: [: too many arguments".
# On first glance something like
#    grep -q "SELINUX=enforcing" $TARGET_FS_ROOT/etc/selinux/config
# looks simpler but that would falsely also evaluate to 'true'
# when grep finds it in comments like '# SELINUX=enforcing'
# but grep still finds it in comments like '#SELINUX=enforcing'
# (i.e. when the comment is one word) so that probably
#    grep -q '^SELINUX=enforcing$' $TARGET_FS_ROOT/etc/selinux/config
# implements what is actually meant to be tested here but the latter
# probably falsely fails for 'SELINUX=enforcing ' (i.e. trailing space).
# TODO: Is this a standard path for the selinux config file?
test $( grep "SELINUX=enforcing" $TARGET_FS_ROOT/etc/selinux/config ) || return 0

LogUserOutput "
SELinux is currently set to enforcing mode.
Relabeling of the root filesystem may be required
in order to allow login of the restored system."

# When USER_INPUT_SELINUX_RELABEL_ON_NEXT_BOOT has any 'true' value be liberal in what you accept and assume exactly 'y' was actually meant:
is_true "$USER_INPUT_SELINUX_RELABEL_ON_NEXT_BOOT" && USER_INPUT_SELINUX_RELABEL_ON_NEXT_BOOT="y"
while true ; do
    # According to what is shown to the user "Relabeling ... required ... to allow login"
    # the default (i.e. the automated response after the timeout) should be 'y':
    answer="$( UserInput -I SELINUX_RELABEL_ON_NEXT_BOOT -p "Would you like to relabel on next boot? (y/n)" -D 'y' )"
    is_false "$answer" && break
    if is_true "$answer" ; then
        touch $TARGET_FS_ROOT/.autorelabel
        break
    fi
    UserOutput "Please answer 'y' or 'n'"
done

