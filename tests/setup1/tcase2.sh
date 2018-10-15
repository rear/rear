#!/bin/bash

unset CONFIG_DIR

export SIMPLIFY_BONDING=y
export SIMPLIFY_BRIDGE=y

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/run.sh
