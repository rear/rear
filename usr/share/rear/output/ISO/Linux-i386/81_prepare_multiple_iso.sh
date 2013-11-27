# 81_prepare_multiple_iso.sh
#
# multiple isos preparation
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

[[ -n $ISO_MAX_SIZE ]] || return

local backup_path=$(url_path $BACKUP_URL)
local isofs_path=$(dirname $backuparchive)

# in mkrescue workflow there is no need to check the backups made, otherwise, 
# NB_ISOS=(ls . | wc -l) [side effect is that lots of empty ISOs are made]
[[ "$WORKFLOW" = "mkrescue" ]] && return

NB_ISOS=$(ls $backuparchive.?? | wc -l)

Print "Preparing $NB_ISOS ISO images ..."
echo -n "$(basename $backuparchive.00)" >> "${isofs_path}/backup.splitted"
echo -n " $(stat -c '%s' $backuparchive.00)" >> "${isofs_path}/backup.splitted"
echo " ${ISO_VOLID}" >> "${isofs_path}/backup.splitted"

for i in `seq -f '%02g' 1 $(($NB_ISOS-1))`; do
    TEMP_ISO_DIR="${TMP_DIR}/isofs_${i}"
    TEMP_BACKUP_DIR="${TEMP_ISO_DIR}${backup_path}"
    BACKUP_NAME="$backuparchive.$i"
    ISO_NAME="${ISO_PREFIX}_${i}.iso"
    ISO_OUTPUT_PATH="${ISO_DIR}/${ISO_NAME}"
    
    echo -n "$(basename $BACKUP_NAME)" >> "${isofs_path}/backup.splitted"
    echo -n " $(stat -c '%s' $BACKUP_NAME)" >> "${isofs_path}/backup.splitted"
    echo " ${ISO_VOLID}_${i}" >> "${isofs_path}/backup.splitted"
    
    mkdir -p $TEMP_BACKUP_DIR
    mv $BACKUP_NAME $TEMP_BACKUP_DIR
    
    LogPrint "Making additionnal ISO image : ${ISO_NAME}"

    pushd $TEMP_ISO_DIR >&8
    $ISO_MKISOFS_BIN $v -o "${ISO_OUTPUT_PATH}" -R -J -volid "${ISO_VOLID}_${i}" -v -iso-level 3 .  >&8
    StopIfError "Could not create ISO image ${ISO_NAME} (with $ISO_MKISOFS_BIN)"
    popd >&8

    ISO_IMAGES=( "${ISO_IMAGES[@]}" "${ISO_OUTPUT_PATH}" )
    iso_image_size=( $(du -h "${ISO_OUTPUT_PATH}") )
    LogPrint "Wrote ISO image: ${ISO_OUTPUT_PATH} ($iso_image_size)"

    # Add ISO image to result files
    RESULT_FILES=( "${RESULT_FILES[@]}" "${ISO_OUTPUT_PATH}" )
done
