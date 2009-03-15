# finished putting together new system, print layout
LogPrint "Recreated this filesystem layout:
$(df -h | grep -v -E '(^none|:|//|/tmp/rear|/ramdisk)')"

