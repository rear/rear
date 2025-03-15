# make LAYOUT_TODO file uniq, but we do not change the order in any way
# See details in issue #3400
unique_unsorted  $LAYOUT_TODO >${LAYOUT_TODO}.new
mv -f ${LAYOUT_TODO}.new $LAYOUT_TODO
