name = rear
#version = $(shell awk '/^Version: / { print $$2}' $(name).spec)
version = $(shell awk 'BEGIN { FS="=" } /^VERSION=/ { print $$2}' usr/sbin/rear)

git_ref = $(shell git symbolic-ref -q HEAD)
git_branch ?= $(lastword $(subst /, ,$(git_ref)))
git_branch ?= HEAD

prefix = /usr
sysconfdir = /etc
sbindir = $(prefix)/sbin
datadir = $(prefix)/share
mandir = $(datadir)/man
localstatedir = /var

all: help

help:
	@echo -e "Rear make targets. \n\
\n\
  validate        - Check source code\n\
  install         - Install Rear to DESTDIR (may replace files)\n\
  uninstall       - Uninstall Rear from DESTDIR (may remove files)\n\
  dist            - Create tar file\n\
  deb             - Create DEB package\n\
  rpm             - Create RPM package\n\
"

clean:

validate:
	find . -name '*.sh' -exec bash -n {} \;

install: validate
	install -d -m0755 $(DESTDIR)$(mandir)/man8/
	install -d -m0755 $(DESTDIR)$(datadir)/rear/
	cp -a usr/share/rear/. $(DESTDIR)$(datadir)/rear/
	-find $(DESTDIR)$(datadir)/rear/ -name '.gitignore' -exec rm -rf {} \; &>/dev/null
	install -d -m0755 $(DESTDIR)$(sysconfdir)/rear/
	cp -a etc/rear/{mappings,templates} $(DESTDIR)$(sysconfdir)/rear/
	-find $(DESTDIR)$(sysconfdir)/rear/ -name '.gitignore' -exec rm -rf {} \; &>/dev/null
	install -d -m0755 $(DESTDIR)$(sbindir)
	install -Dp -m0755 usr/sbin/rear $(DESTDIR)$(sbindir)/rear
	install -d -m0755 $(DESTDIR)$(localstatedir)/lib/rear
	sed -i -e 's#^CONFIG_DIR=.*#CONFIG_DIR="$(sysconfdir)/rear"#' \
		-e 's#^SHARE_DIR=.*#SHARE_DIR="$(datadir)/rear"#' \
		-e 's#^VAR_DIR=.*#VAR_DIR="$(localstatedir)/lib/rear"#' \
		$(DESTDIR)$(sbindir)/rear
	sed -e 's#/etc#$(sysconfdir)#' \
		-e 's#/usr/sbin#$(sbindir)#' \
		-e 's#/usr/share#$(datadir)#' \
		-e 's#/usr/share/doc/packages#$(datadir)/doc#' \
		doc/rear.8 >$(DESTDIR)$(mandir)/man8/rear.8

uninstall:
	-rm -v $(DESTDIR)$(sbindir)/rear
	-rm -v $(DESTDIR)$(mandir)/man8/rear.8
	-rm -rv $(DESTDIR)$(datadir)/rear/
#	rm -rv $(DESTDIR)$(sysconfdir)/rear/
#	rm -rv $(DESTDIR)$(localstatedir)/lib/rear/

dist: clean validate
	git ls-tree -r --name-only --full-tree $(git_branch) | \
	sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/' | \
	pax -d -w -x ustar -s ,^,$(name)-$(version)/, | \
	bzip2 >$(name)-$(version).tar.bz2

rpm: dist
#	rpmbuild -tb --clean --rmspec --define "_rpmfilename %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm" --define "_rpmdir %(pwd)" $(name)-$(version).tar.bz2
	rpmbuild -bb --clean \
	--define "_rpmfilename %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm" \
	--define "_rpmdir %(pwd)" contrib/$(name).spec
