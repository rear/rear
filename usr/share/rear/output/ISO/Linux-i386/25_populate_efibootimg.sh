# 25_populate_efibootimg.sh

(( USING_UEFI_BOOTLOADER )) || return    # empty or 0 means NO UEFI

mkdir $v -p $TMP_DIR/mnt/EFI/BOOT >&2
StopIfError "Could not create $TMP_DIR/mnt/EFI/BOOT"

mkdir $v -p $TMP_DIR/mnt/EFI/BOOT/fonts >&2
StopIfError "Could not create $TMP_DIR/mnt/EFI/BOOT/fonts"

mkdir $v -p $TMP_DIR/mnt/EFI/BOOT/locale >&2
StopIfError "Could not create $TMP_DIR/mnt/EFI/BOOT/locale"

# copy the grub*.efi executable to EFI/BOOT/BOOTX64.efi 
cp  $v "${UEFI_BOOTLOADER}" $TMP_DIR/mnt/EFI/BOOT/BOOTX64.efi >&2
StopIfError "Could not find ${UEFI_BOOTLOADER}"

if [[ -n "$(type -p grub)" ]]; then
cat > $TMP_DIR/mnt/EFI/BOOT/BOOTX64.conf << EOF
default=0
timeout 5
splashimage=/EFI/BOOT/splash.xpm.gz
title Relax and Recover (no Secure Boot)
    kernel /isolinux/kernel
    initrd /isolinux/initrd.cgz

EOF
else
# create small embedded grub.cfg file for grub-mkimage
cat > $TMP_DIR/mnt/EFI/BOOT/embedded_grub.cfg <<EOF
set prefix=(cd0)/EFI/BOOT
configfile /EFI/BOOT/grub.cfg
EOF

# create a grub.cfg
cat > $TMP_DIR/mnt/EFI/BOOT/grub.cfg << EOF
set default="0"

insmod efi_gop
insmod efi_uga
insmod video_bochs
insmod video_cirrus
insmod all_video

set gfxpayload=keep
insmod gzio
insmod part_gpt
insmod ext2

set timeout=5

search --no-floppy --file /boot/efiboot.img --set
#set root=(cd0)

menuentry "Relax and Recover (no Secure Boot)"  --class gnu-linux --class gnu --class os {
     echo 'Loading kernel ...'
     linux /isolinux/kernel
     echo 'Loading initial ramdisk ...'
     initrd /isolinux/initrd.cgz
}

menuentry "Relax and Recover (Secure Boot)"  --class gnu-linux --class gnu --class os {
     echo 'Loading kernel ...'
     linuxefi /isolinux/kernel
     echo 'Loading initial ramdisk ...'
     initrdefi /isolinux/initrd.cgz
}

menuentry "Reboot" {
     reboot
}

menuentry "Exit to EFI Shell" {
     quit
}
EOF
fi
# create BOOTX86.efi
build_bootx86_efi

# we will be using grub-efi or grub2 (with efi capabilities) to boot from ISO
grubdir=$(ls -d /boot/grub*)
[[ ! -d $grubdir ]] && grubdir=/boot/grub

if [ -d $(dirname ${UEFI_BOOTLOADER})/fonts ]; then
    cp $v $(dirname ${UEFI_BOOTLOADER})/fonts/* $TMP_DIR/mnt/EFI/BOOT/fonts/ >&2
    StopIfError "Could not copy $(dirname ${UEFI_BOOTLOADER})/fonts/ files"
elif [ -d $grubdir/fonts ]; then
    cp $v $grubdir/fonts/* $TMP_DIR/mnt/EFI/BOOT/fonts/ >&2
    StopIfError "Could not copy $grubdir/fonts/ files"
else
    Log "Warning: did not find $grubdir/fonts directory (UEFI ISO boot in danger)"
fi

if [ -d $grubdir/locale ]; then
    cp $v $grubdir/locale/* $TMP_DIR/mnt/EFI/BOOT/locale/ >&2
    StopIfError "Could not copy $grubdir/locale/ files"
else
    Log "Warning: did not find $grubdir/locale directory (minor issue)"
fi

# copy of efiboot content also the our ISO tree (isofs/)
mkdir $v -p -m 755 $TMP_DIR/isofs/EFI/BOOT >&2
cp $v -r $TMP_DIR/mnt/EFI  $TMP_DIR/isofs/ >&2
StopIfError "Could not create the isofs/EFI/BOOT directory on the ISO image"

# make /boot/grub/grub.cfg available on isofs/
mkdir $v -p -m 755 $TMP_DIR/isofs/boot/grub >&2
if [[ -n "$(type -p grub)" ]]; then
    cp $v $TMP_DIR/isofs/EFI/BOOT/BOOTX64.conf  $TMP_DIR/isofs/boot/grub/ >&2
else
    cp $v $TMP_DIR/isofs/EFI/BOOT/grub.cfg  $TMP_DIR/isofs/boot/grub/ >&2
fi

StopIfError "Could not copy grub config file to isofs/boot/grub"

ISO_FILES=( "${ISO_FILES[@]}" )
