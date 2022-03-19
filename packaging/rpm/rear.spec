%define rpmrelease %{nil}
%define debug_package %{nil}

### Work-around the fact that openSUSE/SLES _always_ defined both :-/
%if 0%{?sles_version} == 0
%undefine sles_version
%endif

Summary: Relax-and-Recover is a Linux disaster recovery and system migration tool
Name: rear
Version: 2.6
Release: 1%{?rpmrelease}%{?dist}
# Since some time the license value 'GPLv3' causes build failures in the openSUSE Build Service
# cf. https://github.com/rear/rear/issues/2289#issuecomment-559713101
# so we use now 'GPL-3.0' that is known to work (at least for now) according to
# https://github.com/rear/rear/issues/2289#issuecomment-576625186
License: GPL-3.0
Group: Applications/File
URL: http://relax-and-recover.org/

# as GitHub stopped with download section we need to go back to Sourceforge for downloads
Source: https://sourceforge.net/projects/rear/files/rear/%{version}/rear-%{version}.tar.gz

# BuildRoot: is required for SLES 11 and RHEL/CentOS 5 builds on openSUSE Build Service (#2135)
BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

# rear contains only bash scripts plus documentation so that on first glance it could be "BuildArch: noarch"
# but actually it is not "noarch" because it only works on those architectures that are explicitly supported.
# Of course the rear bash scripts can be installed on any architecture just as any binaries can be installed on any architecture.
# But the meaning of architecture dependent packages should be on what architectures they will work.
# Therefore only those architectures that are actually supported are explicitly listed.
# This avoids that rear can be "just installed" on architectures that are actually not supported (e.g. ARM or IBM z Systems):
ExclusiveArch: %ix86 x86_64 ppc ppc64 ppc64le ia64
# Furthermore for some architectures it requires architecture dependent packages (like syslinux for x86 and x86_64)
# so that rear must be architecture dependent because ifarch conditions never match in case of "BuildArch: noarch"
# see the GitHub issue https://github.com/rear/rear/issues/629
%ifarch %ix86 x86_64
Requires: syslinux
%endif
# In the end this should tell the user that rear is known to work only on ix86 x86_64 ppc ppc64 ppc64le ia64
# and on ix86 x86_64 syslinux is explicitly required to make the bootable ISO image
# (in addition to the default installed bootloader grub2) while on ppc ppc64 the
# default installed bootloader yaboot is also used to make the bootable ISO image.

BuildRequires: make

### Mandatory dependencies on all distributions:
Requires: binutils
Requires: ethtool
Requires: gzip
Requires: iputils
Requires: parted
Requires: tar
Requires: openssl
Requires: gawk
Requires: attr
Requires: bc

### Non-mandatory dependencies should be specified as RPM weak dependency via
### Recommends: RPM_package_name
### because missing RPM Recommends do not cause hard errors during installation
### and using Recommends instead of Requires has the additional advantage
### that the user can use ReaR without unneeded hard requirements when
### he does not use functionality in ReaR that uses the hard requirements
### e.g. when he does not need genisoimage or mkisofs to make an ISO image
### (i.e. when he does not use "OUTPUT=ISO"), cf.
### https://github.com/rear/rear/issues/2289
### When particular functionality in ReaR requires certain programs
### those programs need to be specified in the ReaR scripts in the
### REQUIRED_PROGS config array but not here in the RPM spec file.

### If you require NFS, you may need the below packages
#Requires: nfsclient portmap rpcbind

### We drop LSB requirements because it pulls in too many dependencies
### The OS is hardcoded in /etc/rear/os.conf instead
#Requires: redhat-lsb

### Required for Bacula/MySQL support
#Requires: bacula-mysql

### Required for OBDR
#Requires: lsscsi sg3_utils

### Optional requirement
#Requires: cfg2html

%if %{?suse_version:1}0
Requires: iproute2
### Since SLES11 there is an extra nfs-client package:
Recommends: nfs-client
### In SLES11 and SLES12 there is
### /usr/bin/genisoimage provided by the genisoimage RPM and there is
### /usr/bin/mkisofs provided by the cdrkit-cdrtools-compat RPM and
### both RPMs are installed by default.
### In openSUSE Leap 15.0 and SLES15 there is (at least by default)
### no longer /usr/bin/genisoimage but there is
### only /usr/bin/mkisofs provided by the mkisofs RPM
### so we recommend all of them to get any of them if available:
Recommends: cdrkit-cdrtools-compat
Recommends: genisoimage
Recommends: mkisofs
%endif

%if %{?mandriva_version:1}0
Requires: iproute2
### Mandriva switched from 2008 away from mkisofs,
### and as a specialty call the package cdrkit-genisoimage!
%if 0%{?mandriva_version} >= 2008
Requires: cdrkit-genisoimage
%else
Requires: mkisofs
%endif
#Requires: lsb
%endif

### On RHEL/Fedora the genisoimage packages provides mkisofs
%if %{?centos_version:1}%{?fedora:1}%{?rhel_version:1}0
Requires: iproute
#Requires: mkisofs
Requires: genisoimage
#Requires: redhat-lsb
%endif

# Note that CentOS also has rhel defined so there is no need to use centos
%if 0%{?rhel}
Requires: util-linux
%endif

%description
Relax-and-Recover is the leading Open Source disaster recovery and system
migration solution. It comprises of a modular
frame-work and ready-to-go workflows for many common situations to produce
a bootable image and restore from backup using this image. As a benefit,
it allows to restore to different hardware and can therefore be used as
a migration tool as well.

Currently Relax-and-Recover supports various boot media (incl. ISO, PXE,
OBDR tape, USB or eSATA storage), a variety of network protocols (incl.
sftp, ftp, http, nfs, cifs) as well as a multitude of backup strategies
(incl.  IBM TSM, MircroFocus Data Protector, Symantec NetBackup, EMC NetWorker,
Bacula, Bareos, BORG, Duplicity, rsync).

Relax-and-Recover was designed to be easy to set up, requires no maintenance
and is there to assist when disaster strikes. Its setup-and-forget nature
removes any excuse for not having a disaster recovery solution implemented.

Professional services and support are available.

%pre
if [ $1 -gt 1 ] ; then
# during upgrade remove obsolete directories
%{__rm} -rf %{_datadir}/rear/output/NETFS
fi

%prep
%setup -q

%check
%{__make} validate

%build

%install
%{__rm} -rf %{buildroot}
%{__make} install DESTDIR="%{buildroot}"

%files
# defattr: is required for SLES 11 and RHEL/CentOS 5 builds on openSUSE Build Service (#2135)
%defattr(-, root, root, 0755)
%doc MAINTAINERS COPYING README.adoc doc/*.txt
%doc %{_mandir}/man8/rear.8*
%config(noreplace) %{_sysconfdir}/rear/
%config(noreplace) %{_sysconfdir}/rear/cert/
%{_datadir}/rear/
%{_localstatedir}/lib/rear/
%{_sbindir}/rear

%changelog
* Thu Jul 30 2015 Johannes Meixner <jsmeix@suse.de>
- For a changelog see the rear-release-notes.txt file.

