#
REQUIRED_PROGS+=( ldconfig )
# On Ubuntu (at least on 16.04) ldconfig is a script that calls ldconfig.real
# so that also ldconfig.real (if exists) is needed in the recovery system
# see https://github.com/rear/rear/issues/1504
PROGS+=( ldconfig.real )
COPY_AS_IS+=( /etc/ld.so.conf /etc/ld.so.conf.d/* )
