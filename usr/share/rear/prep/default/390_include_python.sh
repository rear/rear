# shellcheck disable=SC2207,SC2168
# include Python

is_false "$PYTHON_INTERPRETER" && return 0

# If the user has not specified a Python interpreter, try to find one
if ! test -x "$PYTHON_INTERPRETER"; then
    read -r PYTHON_INTERPRETER < <(type -p python python3) || Error "Could not find suitable Python searching for python python3"
fi

# Check for minimum Python version, I don't want to deal with Python 2 syntax early 3 issues
"$PYTHON_INTERPRETER" -c 'import sys; sys.version_info >= (3, 4) or sys.exit(1)' ||
    Error "Python interpreter $PYTHON_INTERPRETER is too old, $PRODUCT requires Python 3.4 or newer to support PYTHON_INTERPRETER"


# Determine Python directories but take only those that have "/python" in the path to filter out generic library directories
# and only those that do not have "site-packages" or "dist-packages" in the path to filter out site-specific directories
COPY_AS_IS+=(
    $("$PYTHON_INTERPRETER" -c 'import sys, re; print("\n".join(filter(lambda x: re.match(r"^(?!.*(?:site|dist)-packages).*\/python.*", x), sys.path)))')
) || Error "Could not determine Python directories"

local python_dist_dirs
python_dist_dirs=(
        $("$PYTHON_INTERPRETER" -c 'import sys, re; print("\n".join(filter(lambda x: re.match(r".*\/python.*(?:site|dist)-packages", x), sys.path)))')
    ) || Error "Could not determine Python directories for PYTHON_MINIMAL=false"

if is_false "$PYTHON_MINIMAL" ; then
    LogPrint "Using $PYTHON_INTERPRETER as Python interpreter and including all site/dist packages"
    COPY_AS_IS+=( "${python_dist_dirs[@]}")
    # Determine the binaries of all installed Python modules by quering pip
    # This is a bit hacky but the only way I found to get the binaries of all installed Python modules
    # The output of pip show --files is a YAML file that contains a list of files for each module
    # We filter out all files that are not in a "/bin" directory and then resolve the path to the binary
    # This is necessary because the path to the binary is relative to the module location
    #
    # The output of this command is a list of paths to binaries of all installed Python modules
    # There is a bug in pip that causes a logging error for module authors with non-ASCII characters in their
    # name, this is why we redirect stderr to /dev/null
    #
    # Note: This code may only use standard library modules because we the case of a naked Python installation
    #       without any extra modules. The only dependency is on pip and we fail if it is not present.
    local python_module_bin_paths
    python_module_bin_paths=(
        $(
            "$PYTHON_INTERPRETER" <<EOF

import sys, subprocess, json, pip
from pathlib import Path

modules_json = subprocess.check_output(
        [sys.executable, "-m", "pip", "--disable-pip-version-check", "list", "--format=json"]
    ).decode("utf-8")
modules = [module_data["name"] for module_data in json.loads(modules_json)]

module_name = None
module_location = None
for line in subprocess.check_output(
        [sys.executable, "-m", "pip", "--disable-pip-version-check", "show", "--files"] + modules,
        stderr=subprocess.DEVNULL
    ).decode("utf-8").splitlines():
    if "Name: " in line:
        module_name = line.split(":")[1].strip()
        print("PROCESSING " + module_name, file=sys.stderr)
    elif "Location: " in line:
        module_location = Path(line.split(":")[1].strip())
    elif "/bin/" in line:
        print(Path(module_location / Path(line.strip())).resolve())

EOF
        )
    ) || Error "Could not determine Python module binaries for PYTHON_MINIMAL=false, make sure pip is installed"

    # add module binaries only to PROGS and not REQUIRED_PROGS because some might actually be missing, 
    # e.g. pip is missing on OL8u7 but pip3 is present even though the pip module installs pip and pip3.6
    # but not pip3
    PROGS+=("${python_module_bin_paths[@]}")
else
    LogPrint "Using $PYTHON_INTERPRETER as Python interpreter and excluding all site/dist packages"
    # make sure that the site and dist packages are not copied, even if they are under the normal Python library path
    COPY_AS_IS_EXCLUDE+=( "${python_dist_dirs[@]}" )
fi

if test -L "$PYTHON_INTERPRETER"; then
    # If the Python interpreter is a symlink, then we add both the symlink target to COPY_AS_IS
    # in case something depends on the symlink target
    COPY_AS_IS+=( "$(readlink -f "$PYTHON_INTERPRETER")" )
fi
# add Python interpreter
REQUIRED_PROGS+=( "$PYTHON_INTERPRETER" )
