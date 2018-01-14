#librsync may be in different Directories on Debian, depending on the Architecture
LIBS=(
"${LIBS[@]}"
$(find /usr/lib /usr/lib64 -name librsync.so.1 || LogPrint "Warning: librsync.so.1 not found! Restore may not work!")
)
