# build/GNU/Linux/45_symlink_mingetty.sh

[[ -f "$ROOTFS_DIR/bin/mingetty" ]] && return  # no need to create a symlink to mingetty

(
    cd  $ROOTFS_DIR/bin
    [[ -f getty ]]  && ln -sf $v getty mingetty
    [[ -f agetty ]] && ln -sf $v agetty mingetty
)
