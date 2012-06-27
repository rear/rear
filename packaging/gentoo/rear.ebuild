# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=4

DESCRIPTION="Fully automated disaster recovery supporting a broad variety of backup strategies and scenarios"
HOMEPAGE="http://relax-and-recover.org/"
SRC_URI="mirror://github/downloads/rear/rear/${P}.tar.gz"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="~amd64 ~x86"
IUSE="udev"

RDEPEND="net-dialup/mingetty
	net-fs/nfs-utils
	sys-apps/iproute2
	sys-apps/lsb-release
	sys-apps/util-linux
	sys-block/parted
	sys-boot/syslinux
	virtual/cdrtools
	udev? ( sys-fs/udev )
"

src_install () {
	if use udev; then
		insinto /lib/udev/rules.d
		doins etc/udev/rules.d/62-rear-usb.rules
	fi

	insinto /etc
	doins -r etc/rear/

	# copy main script-file and docs
	dosbin usr/sbin/rear
	doman usr/share/rear/doc/rear.8
	dodoc README

	insinto /usr/share/
	doins -r usr/share/rear/
}