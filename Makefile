### Get version from rear itself
name = rear
version = $(shell awk 'BEGIN { FS="=" } /^VERSION=/ { print $$2}' usr/sbin/rear)
date = $(shell date +%Y%m%d%H%M)

### Get the branch information from git
git_ref = $(shell git symbolic-ref -q HEAD)
git_branch ?= $(lastword $(subst /, ,$(git_ref)))
git_branch ?= HEAD

prefix = /usr
sysconfdir = /etc
sbindir = $(prefix)/sbin
datadir = $(prefix)/share
mandir = $(datadir)/man
localstatedir = /var

all:
	@echo "Nothing to build. Use \`make help' for more information."

help:
	@echo -e "Rear make targets: \n\
\n\
  validate        - Check source code\n\
  install         - Install Rear to DESTDIR (may replace files)\n\
  uninstall       - Uninstall Rear from DESTDIR (may remove files)\n\
  dist            - Create tar file\n\
  deb             - Create DEB package\n\
  rpm             - Create RPM package\n\
\n\
Rear make variables (optional):\n\
\n\
  DESTDIR=        - Location to install/uninstall\n\
  git_branch=     - Branch to use (make sure this matches your checkout)\n\
"

clean:

validate:
	@echo -e "\033[1m== Validating scripts and configuration ==\033[0;0m"
	find etc/ usr/share/rear/conf/ -name '*.conf' | xargs bash -n
	bash -n usr/sbin/rear
	find . -name '*.sh' | xargs bash -n
	find -L . -type l

install-config:
	@echo -e "\033[1m== Installing configuration ==\033[0;0m"
	install -d -m0755 $(DESTDIR)$(sysconfdir)/rear/
	cp -a etc/rear/{mappings,templates} $(DESTDIR)$(sysconfdir)/rear/
	-find $(DESTDIR)$(sysconfdir)/rear/ -name '.gitignore' -exec rm -rf {} \; &>/dev/null

install-bin:
	@echo -e "\033[1m== Installing binary ==\033[0;0m"
	install -Dp -m0755 usr/sbin/rear $(DESTDIR)$(sbindir)/rear
	sed -i -e 's#^CONFIG_DIR=.*#CONFIG_DIR="$(sysconfdir)/rear"#' \
		-e 's#^SHARE_DIR=.*#SHARE_DIR="$(datadir)/rear"#' \
		-e 's#^VAR_DIR=.*#VAR_DIR="$(localstatedir)/lib/rear"#' \
		$(DESTDIR)$(sbindir)/rear

install-data:
	@echo -e "\033[1m== Installing scripts ==\033[0;0m"
	install -d -m0755 $(DESTDIR)$(datadir)/rear/
	cp -a usr/share/rear/. $(DESTDIR)$(datadir)/rear/
	-find $(DESTDIR)$(datadir)/rear/ -name '.gitignore' -exec rm -rf {} \; &>/dev/null

install-var:
	@echo -e "\033[1m== Installing working directory ==\033[0;0m"
	install -d -m0755 $(DESTDIR)$(localstatedir)/lib/rear

install-doc:
	@echo -e "\033[1m== Installing documentation ==\033[0;0m"
	install -Dp -m0755 doc/rear.8 $(DESTDIR)$(mandir)/man8/rear.8
	sed -i -e 's#/etc#$(sysconfdir)#' \
		-e 's#/usr/sbin#$(sbindir)#' \
		-e 's#/usr/share#$(datadir)#' \
		-e 's#/usr/share/doc/packages#$(datadir)/doc#' \
		$(DESTDIR)$(mandir)/man8/rear.8

install: validate install-config install-bin install-data install-var install-doc

uninstall:
	@echo -e "\033[1m== Uninstalling Rear ==\033[0;0m"
	-rm -v $(DESTDIR)$(sbindir)/rear
	-rm -v $(DESTDIR)$(mandir)/man8/rear.8
	-rm -rv $(DESTDIR)$(datadir)/rear/
#	rm -rv $(DESTDIR)$(sysconfdir)/rear/
#	rm -rv $(DESTDIR)$(localstatedir)/lib/rear/

dist: clean validate
	@echo -e "\033[1m== Building archive ==\033[0;0m"
	git ls-tree -r --name-only --full-tree $(git_branch) | \
	pax -d -w -x ustar -s ,^,$(name)-$(version)/, | \
	bzip2 >$(name)-$(version).tar.bz2

update-spec:
	@echo -e "\033[1m== Update RPM spec file ==\033[0;0m"
	sed -i \
	-e 's#^Source:.*#Source: $(name)-$(version)-$(date)-$(git_branch).tar.bz2#' \
	-e 's#^\(Release: *[0-9]\+\)#\1.git$(date)#' \
	contrib/$(name).spec

build-tar:
	@echo -e "\033[1m== Building archive ==\033[0;0m"
	git ls-tree -r --name-only --full-tree $(git_branch) | \
	pax -d -w -x ustar -s ,^,$(name)-$(version)/, | \
	bzip2 >$(name)-$(version)-$(date)-$(git_branch).tar.bz2

restore-spec:
	@echo -e "\033[1m== Restore RPM spec file ==\033[0;0m"
	git checkout contrib/$(name).spec

dist-git: clean validate update-spec build-tar restore-spec

rpm: dist-git
	@echo -e "\033[1m== Building RPM package ==\033[0;0m"
	rpmbuild -tb --clean \
	--define "_rpmfilename %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm" \
	--define "_rpmdir %(pwd)" $(name)-$(version)-$(date)-$(git_branch).tar.bz2
