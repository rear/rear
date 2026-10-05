# Running commands in Docker

`run-in-docker` runs ReaR commands in Docker containers based on supported Linux
distributions. Run it from the root of the ReaR checkout. Docker must be
installed and available to the current user; the script also uses Podman if
Docker is not available.

## Run a command

```shell
tools/run-in-docker [image ...] -- <command> [arguments ...]
```

The image selectors go before `--`; the command and its arguments go after it.
With no selectors, the command runs in every image listed by
`tools/run-in-docker --help`. A selector that matches a listed image name
selects that image (for example, `ubuntu:24.04` or `debian:12`). If it matches
none of the listed images, it is treated as a Docker image name, so you can run
an image of your choice.

Examples:

```shell
# Run a ReaR command in one supported image
tools/run-in-docker ubuntu:24.04 -- rear dump

# Build packages in every supported image
tools/run-in-docker -- make package

# Run a compound shell command in one image
tools/run-in-docker debian:12 -- 'make package || echo "package build failed"'
```

The checkout is mounted at `/rear` in the container, and commands run from
that directory. Changes made to the checkout persist after the container exits.
When a command creates files in the checkout's `dist` directory, the script
copies them to `dist-all/<image>/` (the image name is sanitized for use as a
directory name).

## Interactive shell

Select one image and omit the command to start an interactive Bash shell, or
request one explicitly with `-i`:

```shell
tools/run-in-docker debian:12
tools/run-in-docker registry.suse.com/suse/sle15 -- -i
```

When no command and no image selector are given, the script runs a short Bash
version check in each supported image rather than opening interactive shells.

## Prepare images

The `--patch` special command builds the selected images with the packages
needed to build and run ReaR. It requires Docker Buildx:

```shell
# Prepare every supported image
tools/run-in-docker -- --patch

# Prepare one image
tools/run-in-docker ubuntu:24.04 -- --patch
```

To continue after an image fails to build and record successful image names in
a file:

```shell
tools/run-in-docker -- --patch --continue-and-record-successful images
```

## Architecture

The container uses the host architecture by default. Use `-a` before `--` to
select a different architecture, for example when using an ARM Mac to run an
amd64 image:

```shell
tools/run-in-docker -a amd64 ubuntu:24.04 -- rear dump
```

On Apple Silicon, the script skips selected images known to require an
incompatible x86-64-v3 CPU when `amd64` is requested.
