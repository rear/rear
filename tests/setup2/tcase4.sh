#!/bin/bash

unset CONFIG_DIR
#CONFIG_DIR=/root

export SIMPLIFY_BONDING=y
export SIMPLIFY_BRIDGE=y

for eth in eth2 eth4 eth6 eth8 eth10; do ifdown $eth; done

. ./run.sh

for eth in eth2 eth4 eth6 eth8 vlan3eth10; do ifup $eth; done
