#!/bin/bash

unset CONFIG_DIR

for eth in eth2 eth4 eth6 eth8 eth10 eth12; do ifdown $eth; done

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/run.sh

for eth in eth2 eth4 eth6 eth8 eth10 eth12; do ifup $eth; done
