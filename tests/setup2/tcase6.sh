#!/bin/bash

unset CONFIG_DIR
#CONFIG_DIR=/root

export SIMPLIFY_BONDING=y
export SIMPLIFY_BRIDGE=y

for eth in eth1 eth3 eth5 eth7 eth9; do ifdown $eth; done

. ./run.sh

for eth in eth1 eth3 vlan5eth5 eth7 eth9; do ifup $eth; done
