# Restore the ESP from ReaR rescue image

[[ -d /mnt/local/boot/efi && -d /boot/efi ]] || return

local espfiles
espfiles=$(echo /mnt/local/boot/efi/*)

if [[ -z "$espfiles" ]]; then
    LogPrint "The backup did not restore the EFI System Partition content, recovering it from this ReaR Rescue Image"
    cp -a $v /boot/efi/* /mnt/local/boot/efi/
fi
