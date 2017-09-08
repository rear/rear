# Copied from ../../DUPLICITY/default/600_create_python_symlink.sh for YUM
# make sure we have a symbolic link to the python binary
(
    cd  $ROOTFS_DIR/bin
    for py in $(find . -name "python*" )
    do
        this_py=${py#./*}   # should be without ./
        case $this_py in
            python) break ;;
            python2*|python3*) ln -sf $v $this_py python >&2 ;;
        esac
    done
)

