#!/bin/bash

function tpmpwd_store() {
    # $1 index NV
    # $2 token plaintext

    local ret
    
    tpm2_nvundefine "$1" -C o;tpm2_nvdefine "$1" -C o -s 32; echo -n "$2" | tpm2_nvwrite "$1" -C o -i -; ret=$?
    if [ $ret -ne 0 ]; then
        echo "tpmpwd_store(): tpm2_nvwrite() failed: $ret" >&2
        return $ret
    fi

    return 0
}

function tpmpwd_load() {
    # $1 index NV

    local plain
    local ret

    plain=$(tpm2_nvread "$1" -C o --size=32); ret=$?
    if [ $ret -ne 0 ]; then
        echo "tpmpwd_load(): tpm2_nvread() failed: $ret" >&2
        return $ret
    fi

    echo $plain
    return 0
}
