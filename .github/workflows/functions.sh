# shellcheck shell=bash
# Function to check whether input param is on list of shell scripts
# $1 - <string> absolute path to file
# $@ - <array of strings> list of strings to compare with
# $? - return value - 0 when succes
is_it_script () {
  [ $# -le 1 ] && return 1
  local file="$1"
  shift
  local scripts=("$@")

  [[ " ${scripts[*]} " =~ " ${file} " ]] && return 0 || return 2
}

# Function to check if given file has .sh extension
# https://stackoverflow.com/a/407229
# $1 - <string> absolute path to file
# $? - return value - 0 when succes
check_extension () {
  [ $# -le 0 ] && return 1
  local file="$1"

  [ "${file: -3}" == ".sh" ] && return 0 || return 2
}

# Function to check if given file contain shell shebang (bash or sh)
# https://unix.stackexchange.com/a/406939
# $1 - <string> absolute path to file
# $? - return value - 0 when succes
check_shebang () {
  [ $# -le 0 ] && return 1
  local file="$1"

  if IFS= read -r line < "./${file}" ; then
    case $line in
      "#!/bin/bash") return 0;;
      "#!/bin/sh") return 0;;
      *) return 1
    esac
  fi
}

# Function to prepare string from array of strings where first argument specify one character separator
# https://stackoverflow.com/a/17841619
# $1 - <char> Character used to join elements of array
# $@ - <array of string> list of strings
# return value - string
join_by () {
  local IFS="$1"
  shift
  echo "$*"
}

# Function to get rid of comments represented by '#'
# $1 - file path
# $2 - name of variable where will be stored result array
# $3 - value 1|0 - does file content inline comments?
# $? - return value - 0 when succes
file_to_array () {
  [ $# -le 2 ] && return 1
  local output=()

  [ "$3" -eq 0 ] && readarray output < <(grep -v "^#.*" "$1")                         # fetch array with lines from file while excluding '#' comments  
  [ "$3" -eq 1 ] && readarray output < <(cut -d ' ' -f 1 < <(grep -v "^#.*" "$1"))    # fetch array with lines from file while excluding '#' comments
  clean_array "$2" "${output[@]}" && return 0
}

# Function to get rid of spaces and new lines from array elements
# https://stackoverflow.com/a/9715377
# https://stackoverflow.com/a/19347380
# https://unix.stackexchange.com/a/225517
# $1 - name of variable where will be stored result array
# $@ - source array
# $? - return value - 0 when succes
clean_array () {
  [ $# -le 2 ] && return 1
  local output="$1"
  shift
  local input=("$@")

  for i in "${input[@]}"; do
    eval $output+=\("${i//[$'\t\r\n ']}"\)
  done
}

# Color aliases use echo -e to use them
export NOCOLOR='\033[0m'
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export ORANGE='\033[0;33m'
export BLUE='\033[0;34m'
export YELLOW='\033[1;33m'
export WHITE='\033[1;37m'
