Name: rear
Version: 1.7.22
Release: 1%{?dist}
Summary: Relax and Recover (ReaR) is a Linux Disaster Recovery framework

Group: Productivity/Archiving/Backup
License: GPL v2 or later
URL: http://rear.sourceforge.net
Source0: http://downloads.sourceforge.net/%{name}/%{name}-%{version}.tar.gz
BuildArch: noarch
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root

# all RPM based systems seem to have this and call it the same
Requires:       mingetty binutils iputils tar gzip ethtool syslinux

# if SuSE
%if 0%{?suse_version} != 0
Requires:       iproute2 lsb
# recent SuSE versions have an extra nfs-client package and switched to genisoimage/wodim
%if 0%{?suse_version} >= 1020
Requires:       genisoimage nfs-client
%else
Requires:       mkisofs
%endif
# openSUSE from 11.1 and SLES from 11 uses rpcbind instead of portmap
%if 0%{?suse_version} >= 1110
Requires:	rpcbind
%else
Requires:       portmap
%endif
# end SuSE
%endif

# if Mandriva
%if 0%{?mandriva_version} != 0
Requires:	iproute2 lsb
# Mandriva switched from 2008 away from mkisofs, and as a specialty call the package cdrkit-genisoimage!
%if 0%{?mandriva_version} >= 2008
Requires:	cdrkit-genisoimage rpcbind
%else
Requires:	mkisofs portmap
%endif
# end Mandriva
%endif

# all Red Hat compatible, Scientific Linux and other clones are not yet supported by openSUSE
# Build Server, add more RHEL clones as needed. To make the boolean expression simpler I copy
# this section for each Red Hat OS
%if 0%{?centos_version} != 0
Requires:	iproute redhat-lsb
# Red Hat moved from CentOS/RHEL/SL 6 and Fedora 9 away from mkisofs
%if 0%{?centos_version} >= 600
Requires:	genisoimage rpcbind
%else
Requires:	mkisofs portmap
%endif
# end CentOS
%endif

%if 0%{?rhel_version} != 0
Requires:	iproute redhat-lsb
# Red Hat moved from CentOS/RHEL/SL 6 and Fedora 9 away from mkisofs
%if 0%{?rhel_version} >= 600 
Requires:	genisoimage rpcbind
%else
Requires:	mkisofs portmap
%endif
# end Red Hat Enterprise Linux
%endif

%if 0%{?fedora_version} != 0
Requires:	iproute redhat-lsb
# Red Hat moved from CentOS/RHEL/SL 6 and Fedora 9 away from mkisofs
%if 0%{?fedora_version} >= 9
Requires:	genisoimage rpcbind
%else
Requires:	mkisofs portmap
%endif
# end Fedora
%endif

%description
Relax and Recover (abbreviated rear) is a highly modular disaster recovery
framework for GNU/Linux based systems, but can be easily extended to other
UNIX alike systems. The disaster recovery information (and maybe the backups)
can be stored via the network, local on hard disks or USB devices, DVD/CD-R,
tape, etc. The result is also a bootable image that is capable of booting via
PXE, DVD/CD and USB media.

Relax and Recover integrates with other backup software and provides integrated
bare metal disaster recovery abilities to the compatible backup software.

%prep
%setup -q
 
%build
# no code to compile - all bash scripts

%install

# create directories
mkdir -vp \
	$RPM_BUILD_ROOT%{_mandir}/man8 \
	$RPM_BUILD_ROOT%{_datadir} \
	$RPM_BUILD_ROOT%{_sysconfdir} \
	$RPM_BUILD_ROOT%{_sbindir} \
	$RPM_BUILD_ROOT%{_localstatedir}/lib/rear

# copy rear components into directories
cp -av usr/share/rear $RPM_BUILD_ROOT%{_datadir}/
cp -av usr/sbin/rear $RPM_BUILD_ROOT%{_sbindir}/
cp -av etc/rear $RPM_BUILD_ROOT%{_sysconfdir}/

# patch rear main script with correct locations for rear components
sed -i  -e 's#^CONFIG_DIR=.*#CONFIG_DIR="%{_sysconfdir}/rear"#' \
	-e 's#^SHARE_DIR=.*#SHARE_DIR="%{_datadir}/rear"#' \
	-e 's#^VAR_DIR=.*#VAR_DIR="%{_localstatedir}/lib/rear"#' \
	$RPM_BUILD_ROOT%{_sbindir}/rear

# update man page with correct locations
sed     -e 's#/etc#%{_sysconfdir}#' \
	-e 's#/usr/sbin#%{_sbindir}#' \
	-e 's#/usr/share#%{_datadir}#' \
	-e 's#/usr/share/doc/packages#%{_docdir}#' \
	doc/rear.8 >$RPM_BUILD_ROOT%{_mandir}/man8/rear.8

%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(-,root,root,-)
%doc COPYING CHANGES README AUTHORS TODO doc/*
%{_sbindir}/rear
%{_datadir}/rear
%{_localstatedir}/lib/rear
%{_mandir}/man8/rear*
%config(noreplace) %{_sysconfdir}/rear


%changelog
* Mon Jan 24 2011 Gratien D'haese <gdha at sourceforge.net> - 1.9-1
- added AUTHORS and TODO to %%doc

* Wed Dec 02 2009 Schlomo Schapiro <rear at schlomo.schapiro.org> - 1.7.22
- updated spec file to be more cross-platform compliant

* Sun Jun 28 2009 Schlomo Schapiro <rear at schlomo.schapiro.org> - 1.7.20-1
- updated spec file to build on SUSE/RHEL/Fedora/Mandriva and clones and use
  the correct dependencies

* Thu Mar 26 2009 Schlomo Schapiro <rear at schlomo.schapiro.org> - 1.7.18
- did http://lists.opensuse.org/opensuse-packaging/2007-02/msg00005.html
  (fix RPM_BUILD_ROOT behaviour)

* Wed Mar 18 2009 Schlomo Schapiro <rear at schlomo.schapiro.org> - 1.7.18
- moved /var/rear to /var/lib/rear
- removed man page gzip

* Sun Mar 15 2009 Schlomo Schapiro <rear at schlomo.schapiro.org> - 1.7.18
- updated spec file to support openSUSE 11.1

* Fri Mar 13 2009 Gratien D'haese <gdha at sourceforge.net> - 1.7.17-1
- do not gzip man page in spec file - rpmbuild will do this for us
- added extra %%doc line for excluding man page from doc itself

* Tue Feb 04 2009 Gratien D'haese <gdha at sourceforge.net> - 1.7.15-1
- update the Fedora spec file with the 1.7.14 items
- added VAR_DIR (%%{_localstatedir}) variable to rear for /var/rear/recovery system data

* Thu Jan 29 2009 Schlomo Schapiro <rear at schlomo.schapiro.org> - 1.7.14-1
- added man page
- patch rear binary to point to correct _datadir and _sysconfdir
- move distribution config files to /usr/share/rear/conf

* Tue Jan 20 2009 Gratien D'haese <gdha at sourceforge.net> - 1.7.13-1
- add COPYING license file

* Wed Dec 17 2008 Gratien D'haese <gdha at sourceforge.net> - 1.7.10-1
- remove contrib entry from %%doc line in spec file

* Mon Dec 01 2008 Gratien D'haese <gdha at sourceforge.net> - 1.7.9-1
- copy rear.sourcespec according OS_VENDOR
- correct rear.spec file according comment 11 of bugzilla #468189

* Mon Oct 27 2008 Gratien D'haese <gdha at sourceforge.net> - 1.7.8-1
- Fix rpmlint error/warnings for Fedora packaging
- updated the Summary line and %%install section

* Thu Oct 24 2008 Gratien D'haese <gdha at sourceforge.net> - 1.7.7-1
- rewrote rear.spec for Fedora Packaging request

* Tue Aug 28 2006 Schlomo Schapiro <rear at schlomo.schapiro.org> - 1.0-1
- Initial RPM Release
