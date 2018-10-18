#!/bin/bash

unset CONFIG_DIR

export SIMPLIFY_BONDING=y
export SIMPLIFY_BRIDGE=y
export SIMPLIFY_TEAMING=y

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/run.sh
