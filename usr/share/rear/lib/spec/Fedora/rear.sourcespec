Name: rear
Version: 1.12.0
Release: 1%{?dist}
Summary: Relax and Recover (Rear) is a Linux Disaster Recovery framework

Group: Applications/Archiving
License: GPLv2+
URL: http://rear.sourceforge.net
Source0: http://downloads.sourceforge.net/%{name}/%{name}-%{version}.tar.gz
BuildArch: noarch

# all RPM based systems seem to have this
Requires: mingetty binutils iputils tar gzip ethtool parted
Requires: iproute redhat-lsb
Requires: genisoimage rpcbind
%ifarch %ix86 x86_64
Requires: syslinux
%endif

%description
Relax and Recover (abbreviated rear) is a highly modular disaster recovery
framework for GNU/Linux based systems, but can be easily extended to other
UNIX alike systems. The disaster recovery information (and maybe the backups)
can be stored via the network, local on hard disks or USB devices, DVD/CD-R,
tape, etc. The result is also a boot-able image that is capable of booting via
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
sed -i	-e 's#^CONFIG_DIR=.*#CONFIG_DIR="%{_sysconfdir}/rear"#' \
	-e 's#^SHARE_DIR=.*#SHARE_DIR="%{_datadir}/rear"#' \
	-e 's#^VAR_DIR=.*#VAR_DIR="%{_localstatedir}/lib/rear"#' \
	$RPM_BUILD_ROOT%{_sbindir}/rear

# update man page with correct locations
sed	-e 's#/etc#%{_sysconfdir}#' \
	-e 's#/usr/sbin#%{_sbindir}#' \
	-e 's#/usr/share#%{_datadir}#' \
	-e 's#/usr/share/doc/packages#%{_docdir}#' \
	doc/rear.8 >$RPM_BUILD_ROOT%{_mandir}/man8/rear.8

# remove doc files under  $RPM_BUILD_ROOT/usr/share/rear
rm -f $RPM_BUILD_ROOT%{_datadir}/rear/README
rm -f $RPM_BUILD_ROOT%{_datadir}/rear/COPYING
rm -f $RPM_BUILD_ROOT%{_datadir}/rear/AUTHORS
rm -f $RPM_BUILD_ROOT%{_datadir}/rear/TODO
rm -rf $RPM_BUILD_ROOT%{_datadir}/rear/doc/*


%files
%defattr(-,root,root,-)
%doc COPYING README AUTHORS TODO
%doc doc/*.txt
%{_sbindir}/rear
%{_datadir}/rear
%{_localstatedir}/lib/rear
%{_mandir}/man8/*
%config(noreplace) %{_sysconfdir}/rear


%changelog
* Sun Mar  4 2012 Peter Robinson <pbrobinson@fedoraproject.org> - 1.12.0-3
- merge F-16 newer version to F-17+
- Clean out long obsolete Fedora versions (F-9) checks

* Sat Jan 14 2012 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 1.12.0-2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_17_Mass_Rebuild

* Mon Nov 21 2011 Gratien D'haese <gdha at sourceforge.net> - 1.12.0-1
- placeholder for release

* Mon Jan 24 2011 Gratien D'haese <gdha at sourceforge.net> - 1.9-1
- New development release with P2V, V2V functionality, and more
- added AUTHORS, TODO to %%doc and rm from datadir

* Fri Jun 04 2010 Gratien D'haese <gdha at sourceforge.net> - 1.7.25-1
- added the %%ifarch part for syslinux to avoid warning on ppc/ppc64

* Thu Apr 02 2009 Gratien D'haese <gdha at sourceforge.net> - 1.7.20-1
- update %%_localstatedir/rear to %%_localstatedir/lib/rear

* Mon Mar 16 2009 Gratien D'haese <gdha at sourceforge.net> - 1.7.19-1
- updated description, made the spec file a bit more readable
- changed BuildArchives in BuildArch

* Fri Mar 13 2009 Gratien D'haese <gdha at sourceforge.net> - 1.7.17-1
- do not gzip man page in spec file - rpmbuild will do this for us
- added extra %%doc line for excluding man page from doc itself

* Tue Feb 04 2009 Gratien D'haese <gdha at sourceforge.net> - 1.7.15-1
- update the Fedora spec file with the 1.7.14 items
- added VAR_DIR (%%{_localstatedir}) variable to rear for /var/rear/recovery system data

* Thu Jan 29 2009 Schlomo Schapiro <rear at schlomo.schapiro.org> - 1.7.14-1
- added man page

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
