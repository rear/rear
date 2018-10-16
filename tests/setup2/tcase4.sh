#!/bin/bash

unset CONFIG_DIR

export SIMPLIFY_BONDING=y
export SIMPLIFY_BRIDGE=y
export SIMPLIFY_TEAMING=y

for eth in eth2 eth4 eth6 eth8 eth10; do ifdown $eth; done

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/run.sh

for eth in eth2 eth4 eth6 eth8 vlan3eth10; do ifup $eth; done
