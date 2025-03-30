#!/bin/bash
# TODO: Add support for GRUB2
# TODO: Use more fine grained OS version detection to install appropriate packages, instead of trial-and-error

exec </dev/null # no interactive input

function die() {
    echo "ERROR: $*" >&2
    exit 1
}

if type -p apt-get &>/dev/null; then
    echo "Patching for Debian"
    export DEBIAN_FRONTEND=noninteractive
    apt-get -y update
    apt-get -y --allow-unauthenticated install \
        sysvinit-utils kbd cpio file procps ethtool iputils-ping net-tools dosfstools binutils parted openssl gawk attr bc psmisc nfs-client portmap xorriso isolinux gdisk syslinux syslinux-common syslinux-efi iproute2 \
        make asciidoctor git build-essential debhelper devscripts || die "Failed to install required packages"
    apt-get -y --allow-unauthenticated install fdisk ||
        apt-get -y --allow-unauthenticated install util-linux || die "Failed to install fdisk or util-linux"

elif type -p zypper &>/dev/null; then
    echo "Patching for SUSE"
    zypper --no-gpg-checks --quiet --non-interactive install \
        sysvinit-tools kbd cpio binutils ethtool gzip iputils parted tar openssl gawk attr bc syslinux portmap rpcbind iproute2 nfs-client xorriso mkisofs util-linux psmisc procps \
        make git rpm-build || die "Failed to install required packages"
    zypper --no-gpg-checks --quiet --non-interactive install 'rubygem(asciidoctor)' ||
        zypper --no-gpg-checks --quiet --non-interactive install asciidoc xmlto || die "Failed to install asciidoctor or asciidoc"

elif type -p pacman &>/dev/null; then
    echo "Patching for Arch"
    pacman --noconfirm -Sy \
        sysvinit-tools kbd cpio binutils ethtool gzip iputils parted tar openssl gawk attr bc syslinux rpcbind iproute2 nfs-utils libisoburn cdrtools util-linux psmisc procps-ng util-linux diffutils less \
        make binutils fakeroot git asciidoctor debugedit || die "Failed to install required packages"

elif type -p yum &>/dev/null; then
    if grep -E '(CentOS.*Final|CentOS Linux release 8)' /etc/redhat-release; then
        echo "Switching to vault repos for CentOS 8"
        sed -i -e 's|#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|' -e '/^mirror/d' /etc/yum.repos.d/*.repo
    fi
    yum -q --nogpgcheck install -y \
        kbd cpio binutils ethtool gzip iputils parted tar openssl gawk attr bc syslinux rpcbind iproute nfs-utils xorriso util-linux psmisc procps-ng util-linux \
        make binutils git rpm-build || die "Failed to install required packages"
    # CentOS 8 doesn't have sysvinit-tools any more but it also doesn't have asciidoctor yet
    # CentOS 10 uses asciidoc and doesn't have sysvinit-tools and also not mkisofs
    yum -q --nogpgcheck install -y sysvinit-tools mkisofs asciidoc xmlto ||
        yum -q --nogpgcheck install -y asciidoctor ||
        yum -q --nogpgcheck install -y mkisofs asciidoc xmlto ||
        yum -q --nogpgcheck install -y asciidoc xmlto ||
        die "Failed to install asciidoctor or asciidoc"
fi

git config --global --add safe.directory /rear || die "Failed to configure git"

exit 0
