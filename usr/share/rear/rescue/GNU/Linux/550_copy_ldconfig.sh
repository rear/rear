#
REQUIRED_PROGS=( ${REQUIRED_PROGS[@]} ldconfig )
PROGS=( "${PROGS[@]}" ldconfig.real )
COPY_AS_IS=( ${COPY_AS_IS[@]} /etc/ld.so.conf /etc/ld.so.conf.d/* )
