
if [[ "$EFI" == "Yes" ]] ; then
    ReaR_Data_Partition_Number=2
else
    ReaR_Data_Partition_Number=1
fi

# Artificial 'for' clause that is run only once
# to be able to 'continue' with the code after it:
for dummy in "once" ; do
    case "$ID_FS_TYPE" in
        ext*)
            USB_LABEL="$( e2label ${RAW_USB_DEVICE}${ReaR_Data_Partition_Number} )"
            test "REAR-000" = "$USB_LABEL" && continue
            LogPrint "Setting filesystem label to REAR-000"
            if ! e2label ${RAW_USB_DEVICE}${ReaR_Data_Partition_Number} REAR-000 ; then
                Error "Could not label '${RAW_USB_DEVICE}${ReaR_Data_Partition_Number}' with REAR-000"
            fi
            USB_LABEL="$( e2label ${RAW_USB_DEVICE}${ReaR_Data_Partition_Number} )"
            ;;
        btrfs)
            USB_LABEL="$( btrfs filesystem label ${RAW_USB_DEVICE}${ReaR_Data_Partition_Number} )"
            test "REAR-000" = "$USB_LABEL" && continue
            LogPrint "Setting filesystem label to REAR-000"
            if ! btrfs filesystem label ${RAW_USB_DEVICE}${ReaR_Data_Partition_Number} REAR-000 ; then
                Error "Could not label '${RAW_USB_DEVICE}${ReaR_Data_Partition_Number}' with REAR-000"
            fi
            USB_LABEL="$( btrfs filesystem label ${RAW_USB_DEVICE}${ReaR_Data_Partition_Number} )"
            ;;
    esac
done
LogPrint "Device '${RAW_USB_DEVICE}${ReaR_Data_Partition_Number}' has label '$USB_LABEL'"

