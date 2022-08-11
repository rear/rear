# Utility functions for working with columns in output of tools.

# Columns have a header. The header fields are separated by at least two spaces.
# These functions expect output like:
# <<
# Model: ATA TOSHIBA MK1652GS (scsi)
# Disk /dev/sda: 160GB
# Sector size (logical/physical): 512B/512B
# Partition Table: msdos
#
# Number  Start   End     Size    Type     File system  Flags
#  1      32.3kB  98.7MB  98.7MB  primary  ext3         boot
#  2      98.7MB  140GB   140GB   primary               lvm
# >>

set_separator() {
    OIFS=$IFS
    IFS="$1"
}

restore_separator() {
    IFS=$OIFS
}

columns=
# produces a list of header=end pairs in $columns
init_columns() {
    local line=$1
    columns=""

    local word=""
    local wasspace=""
    local len=${#line}
    local i=0
    while (( $i < $len )) ;
    do
        local char="${line:$i:1}"
        if [[ "$wasspace" ]] && [[ "$char" = " " ]] ;then
            if [[ "$word" ]] ; then
                # word complete, write to list
                let start=$i-${#word}
                word=$( echo "$word" | tr '[:upper:]' '[:lower:]')

                columns+="${word%% }=$start;"
                word=""
            fi
        else
            word="${word}${char}"
        fi

        if [[ "$char" = " " ]] ; then
            wasspace="yes"
        else
            wasspace=""
        fi

        let i++
    done
    # last word
    let start=$i-${#word}
    word=$( echo "$word"| tr '[:upper:]' '[:lower:]')
    columns+="${word%% }=$start;"

    #echo "c:$columns"
}

# get_column_size $header
get_column_size() {
    local start=$(get_column_start "$1")

    local nextheader=$(get_next_header "$1")
    if [[ -z "$nextheader" ]] ; then
        echo "255"
        return 0
    fi
    local end=$(get_column_start "$nextheader")
    let local size=$end-$start
    echo "$size"
}

# get_column_start $header
get_column_start() {
    local pair
    set_separator ";"
    for pair in $columns ; do
        local header=${pair%=*}
        local hstart=${pair#*=}

        if [[ "$header" = "$1" ]] ; then
            echo "$hstart"
            restore_separator
            return 0
        fi
    done
    restore_separator
    return 1
}

# get_next_header $header
get_next_header() {
    local pair
    local previous
    set_separator ";"
    for pair in $columns ; do
        local header=${pair%=*}
        local hstart=${pair#*=}

        if [[ "$previous" = "$1" ]] ; then
            echo "$header"
            restore_separator
            return 0
        fi

        previous=$header
    done
    restore_separator
    return 1
}

# get_columns $line $header1 $header2
# print the contents of the columns, separated by ;
get_columns() {
    local line=$1
    shift

    local headers=$@
    local value=""
    for header in $headers ; do
        local start=$(get_column_start "$header")
        local size=$(get_column_size "$header")
        #echo "$header $start $size"
        value+="${line:$start:$size};"
    done
    echo "$value"
}
