# build/GNU/Linux/450_symlink_mingetty.sh

[[ -f "$ROOTFS_DIR/bin/mingetty" ]] && return  # no need to create a symlink to mingetty

(
    cd  $ROOTFS_DIR/bin
    [[ -f getty ]]  && ln -sf $v getty mingetty >&2
    [[ -f agetty ]] && ln -sf $v agetty mingetty >&2
)
