# Copyright 1999-2012 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=4

DESCRIPTION="Fully automated disaster Recovery supporting a broad variety of backup strategies and scenarios"
HOMEPAGE="http://rear.github.com/"
SRC_URI="mirror://github/downloads/${PN}/${PN}/${P}.tar.gz"

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
		doins etc/udev/rules.d/62-${PN}-usb.rules
	fi

	insinto /etc
	doins -r etc/${PN}

	# copy main script-file and docs
	dosbin usr/sbin/${PN}
	doman usr/share/${PN}/doc/${PN}.8
	dodoc README

	insinto /usr/share/
	doins -r usr/share/${PN}
}
