#!/bin/bash

CONFIG_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

export SIMPLIFY_BONDING=y
export SIMPLIFY_BRIDGE=y

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/run.sh
