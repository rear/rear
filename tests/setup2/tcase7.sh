#!/bin/bash

CONFIG_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
export CONFIG_DIR

. "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"/run.sh
