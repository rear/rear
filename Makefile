# In some dists (e.g. Ubuntu) bash is not the default shell. Statements like
#   cp -a etc/rear/{mappings,templates} ...
# assumes bash. So its better to set SHELL
SHELL=/bin/bash

DESTDIR =
OFFICIAL =

### Get version from Relax-and-Recover itself
rearbin = usr/sbin/rear
name = rear
version := $(shell awk 'BEGIN { FS="=" } /^readonly VERSION=/ { print $$2}' $(rearbin))

### Get the branch information from git
ifeq ($(OFFICIAL),)
ifneq ($(shell which git),)
git_date := $(shell git log -n 1 --format="%ai" 2>/dev/null || echo now)
git_ref := $(shell git rev-parse --short HEAD 2>/dev/null || echo 0)
git_count := $(shell git rev-list HEAD --count --no-merges 2>/dev/null || echo 0)
git_branch_suffix = $(shell { git symbolic-ref --short HEAD 2>/dev/null || echo unknown ; } | tr -d /_-)
git_status := $(shell git status --porcelain 2>/dev/null)
git_stamp := $(git_count).$(git_ref).$(git_branch_suffix)
ifneq ($(git_status),)
git_stamp := $(git_stamp).changed
endif
endif
else
ifneq ($(shell which git),)
git_date := $(shell git log -n 1 --format="%ai")
endif
git_branch = rear-$(version)
endif
git_branch ?= master

date := $(shell date --date="$(git_date)" +%Y%m%d%H%M)
release_date := $(shell date --date="$(git_date)" +%Y-%m-%d)

prefix = /usr
sysconfdir = /etc
sbindir = $(prefix)/sbin
datadir = $(prefix)/share
mandir = $(datadir)/man
localstatedir = /var

specfile = packaging/rpm/$(name).spec
dscfile = packaging/debian/$(name).dsc

distversion = $(version)
debrelease = 0
rpmrelease = %nil
obsproject = Archiving:Backup:Rear
obspackage = $(name)-$(version)
ifeq ($(OFFICIAL),)
    distversion = $(version)-git.$(git_stamp)
    debrelease = 0git.$(git_stamp)
    rpmrelease = .git.$(git_stamp)
    obsproject = Archiving:Backup:Rear:Snapshot
    obspackage = $(name)
endif

.PHONY: doc

all:
	@echo "Nothing to build. Use \`make help' for more information."

help:
	@echo -e "Relax-and-Recover make targets:\n\
\n\
  validate        - Check source code\n\
  install         - Install Relax-and-Recover (may replace files)\n\
  uninstall       - Uninstall Relax-and-Recover (may remove files)\n\
  dist            - Create tar file in dist/\n\
  deb             - Create DEB package in dist/\n\
  rpm             - Create RPM package in dist/\n\
  pacman          - Create Pacman package\n\
  obs             - Initiate OBS builds\n\
\n\
Relax-and-Recover make variables (optional):\n\
\n\
  DESTDIR=        - Location to install/uninstall\n\
  OFFICIAL=1      - Build an official release\n\
"

clean:
	rm -Rf dist build
	rm -f build-stamp
	make -C doc clean

### You can call 'make validate' directly from your .git/hooks/pre-commit script
validate:
	@echo -e "\033[1m== Validating scripts and configuration ==\033[0;0m"
	find etc/ usr/share/rear/conf/ -name '*.conf' | xargs -n 1 bash -n
	bash -n $(rearbin)
	find . -name '*.sh' | xargs -n 1 bash -O extglob -O nullglob -n
	find usr/share/rear -name '*.sh' | grep -v -E '(lib|skel|conf)' | while read FILE ; do \
		num=$$(echo $${FILE##*/} | cut -c1-3); \
		if [[ "$$num" = "000" || "$$num" = "999" ]] ; then \
			echo "ERROR: script $$FILE may not start with $$num"; \
			exit 1; \
		else \
			if $$( grep '[_[:alpha:]]' <<< $$num >/dev/null 2>&1 ) ; then \
				echo "ERROR: script $$FILE must start with 3 digits"; \
				exit 1; \
			fi; \
		fi; \
	done

man:
	@echo -e "\033[1m== Prepare manual ==\033[0;0m"
	make -C doc man

doc:
	@echo -e "\033[1m== Prepare documentation ==\033[0;0m"
	make -C doc docs

install-config:
	@echo -e "\033[1m== Installing configuration ==\033[0;0m"
	install -d -m0700 $(DESTDIR)$(sysconfdir)/rear/
	install -d -m0700 $(DESTDIR)$(sysconfdir)/rear/cert/
	-[[ ! -e $(DESTDIR)$(sysconfdir)/rear/local.conf ]] && \
		install -Dp -m0600 etc/rear/local.conf $(DESTDIR)$(sysconfdir)/rear/local.conf
	-[[ ! -e $(DESTDIR)$(sysconfdir)/rear/os.conf && -e etc/rear/os.conf ]] && \
		install -Dp -m0600 etc/rear/os.conf $(DESTDIR)$(sysconfdir)/rear/os.conf
	-find $(DESTDIR)$(sysconfdir)/rear/ -name '.gitignore' -exec rm -rf {} \; &>/dev/null

install-bin:
	@echo -e "\033[1m== Installing binary ==\033[0;0m"
	install -Dp -m0755 $(rearbin) $(DESTDIR)$(sbindir)/rear
	sed -i -e 's,^CONFIG_DIR=.*,CONFIG_DIR="$(sysconfdir)/rear",' \
		-e 's,^SHARE_DIR=.*,SHARE_DIR="$(datadir)/rear",' \
		-e 's,^VAR_DIR=.*,VAR_DIR="$(localstatedir)/lib/rear",' \
		$(DESTDIR)$(sbindir)/rear

install-data:
	@echo -e "\033[1m== Installing scripts ==\033[0;0m"
	install -d -m0755 $(DESTDIR)$(datadir)/rear/
	cp -a usr/share/rear/. $(DESTDIR)$(datadir)/rear/
	-find $(DESTDIR)$(datadir)/rear/ -name '.gitignore' -exec rm -rf {} \; &>/dev/null

install-var:
	@echo -e "\033[1m== Installing working directory ==\033[0;0m"
	install -d -m0755 $(DESTDIR)$(localstatedir)/lib/rear/
	install -d -m0755 $(DESTDIR)$(localstatedir)/log/rear/

install-doc:
	@echo -e "\033[1m== Installing documentation ==\033[0;0m"
	make -C doc install
	sed -i -e 's,/etc,$(sysconfdir),' \
		-e 's,/usr/sbin,$(sbindir),' \
		-e 's,/usr/share,$(datadir),' \
		-e 's,/usr/share/doc/packages,$(datadir)/doc,' \
		$(DESTDIR)$(mandir)/man8/rear.8

install: validate man install-config install-bin install-data install-var install-doc

uninstall:
	@echo -e "\033[1m== Uninstalling Relax-and-Recover ==\033[0;0m"
	-rm -v $(DESTDIR)$(sbindir)/rear
	-rm -v $(DESTDIR)$(mandir)/man8/rear.8
	-rm -rv $(DESTDIR)$(datadir)/rear/
#	rm -rv $(DESTDIR)$(sysconfdir)/rear/
#	rm -rv $(DESTDIR)$(localstatedir)/lib/rear/

dist: clean validate man dist/$(name)-$(distversion).tar.gz

dist/$(name)-$(distversion).tar.gz:
	@echo -e "\033[1m== Building archive $(name)-$(distversion) ==\033[0;0m"
	rm -Rf build/$(name)-$(distversion)
	mkdir -p dist build/$(name)-$(distversion)
	tar -c --exclude-from=.gitignore --exclude=.gitignore --exclude=".??*" * | \
		tar -C build/$(name)-$(distversion) -x
	@echo -e "\033[1m== Rewriting $(specfile), $(dscfile) and $(rearbin) ==\033[0;0m"
	sed -i.orig \
		-e 's#^Source:.*#Source: https://sourceforge.net/projects/rear/files/rear/${version}/$(name)-${distversion}.tar.gz#' \
		-e 's#^Version:.*#Version: $(version)#' \
		-e 's#^%define rpmrelease.*#%define rpmrelease $(rpmrelease)#' \
		-e 's#^%setup.*#%setup -q -n $(name)-$(distversion)#' \
		build/$(name)-$(distversion)/$(specfile)
	sed -i.orig \
		-e 's#^Version:.*#Version: $(version)-$(debrelease)#' \
		build/$(name)-$(distversion)/$(dscfile)
	sed -i.orig \
		-e 's#^readonly VERSION=.*#readonly VERSION=$(distversion)#' \
		-e 's#^readonly RELEASE_DATE=.*#readonly RELEASE_DATE="$(release_date)"#' \
		build/$(name)-$(distversion)/$(rearbin)
	tar -czf dist/$(name)-$(distversion).tar.gz -C build $(name)-$(distversion)

srpm: dist
	@echo -e "\033[1m== Building SRPM package $(name)-$(distversion) ==\033[0;0m"
	rpmbuild -ts --clean --nodeps \
		--define="_topdir $(CURDIR)/build/rpmbuild" \
		--define="_sourcedir $(CURDIR)/dist" \
		--define="_srcrpmdir $(CURDIR)/dist" \
		--define "debug_package %{nil}" \
		dist/$(name)-$(distversion).tar.gz

rpm: srpm
	@echo -e "\033[1m== Building RPM package $(name)-$(distversion) ==\033[0;0m"
	rpmbuild --rebuild --clean \
		--define="_topdir $(CURDIR)/build/rpmbuild" \
		--define="_rpmdir $(CURDIR)/dist" \
		--define "_rpmfilename %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm" \
		--define "debug_package %{nil}" \
		dist/$(name)-$(version)-1*.src.rpm

deb: dist
	@echo -e "\033[1m== Building DEB package $(name)-$(distversion) ==\033[0;0m"
	cp -r build/$(name)-$(distversion)/packaging/debian/ build/$(name)-$(distversion)/
	cd build/$(name)-$(distversion) ; dch -v $(distversion) -b -M build package
	cd build/$(name)-$(distversion) ; debuild -us -uc -i -b --lintian-opts --profile debian
	mv build/$(name)_*deb dist/

pacman: BUILD_DIR = /tmp/rear-$(distversion)
pacman: dist
	@echo -e "\033[1m== Building Pacman package $(name)-$(distversion) ==\033[0;0m"
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	cp packaging/arch/PKGBUILD.local $(BUILD_DIR)/PKGBUILD
	cp $(name)-$(distversion).tar.gz $(BUILD_DIR)/
	cd $(BUILD_DIR) ; sed -i -e 's/VERSION/$(date)/' \
		-e 's/SOURCE/$(name)-$(distversion).tar.gz/' \
		-e 's/MD5SUM/$(shell md5sum $(name)-$(distversion).tar.gz | cut -d' ' -f1)/' \
		PKGBUILD ; makepkg -c
	cp $(BUILD_DIR)/*.pkg.* .
	rm -rf $(BUILD_DIR)

obs: BUILD_DIR = /tmp/rear-$(distversion)
obs: obsname = $(shell osc ls $(obsproject) $(obspackage) | awk '/.tar.gz$$/ { gsub(".tar.gz$$","",$$1); print }')
obs: dist
	@echo -e "\033[1m== Updating OBS from $(obsname) to $(name)-$(distversion)== \033[0;0m"
ifneq ($(obsname),$(name)-$(distversion))
	-rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
ifneq ($(OFFICIAL),)
#	osc rdelete -m 'Recreating branch $(obspackage)' $(obsproject) $(obspackage)
	-osc branch Archiving:Backup:Rear:Snapshot rear $(obsproject) $(obspackage)
	-osc detachbranch $(obsproject) $(obspackage)
endif
	(cd $(BUILD_DIR) ; osc co -c $(obsproject) $(obspackage) )
	-(cd $(BUILD_DIR)/$(obspackage) ; osc del *.tar.gz )
	cp dist/$(name)-$(distversion).tar.gz $(BUILD_DIR)/$(obspackage)
	tar -xOzf dist/$(name)-$(distversion).tar.gz -C $(BUILD_DIR)/$(obspackage) $(name)-$(distversion)/$(specfile) >$(BUILD_DIR)/$(obspackage)/$(name).spec
	tar -xOzf dist/$(name)-$(distversion).tar.gz -C $(BUILD_DIR)/$(obspackage) $(name)-$(distversion)/$(dscfile) >$(BUILD_DIR)/$(obspackage)/$(name).dsc
	tar -xOzf dist/$(name)-$(distversion).tar.gz -C $(BUILD_DIR)/$(obspackage) $(name)-$(distversion)/packaging/debian/control >$(BUILD_DIR)/$(obspackage)/debian.control
	tar -xOzf dist/$(name)-$(distversion).tar.gz -C $(BUILD_DIR)/$(obspackage) $(name)-$(distversion)/packaging/debian/rules >$(BUILD_DIR)/$(obspackage)/debian.rules
	echo -e "rear ($(version)-$(debrelease)) stable; urgency=low\n\n  * new snapshot build\n\n -- openSUSE Build Service <obs@relax-and-recover.org>  $$(date -R)" >$(BUILD_DIR)/$(obspackage)/debian.changelog
	tar -xOzf dist/$(name)-$(distversion).tar.gz -C $(BUILD_DIR)/$(obspackage) $(name)-$(distversion)/packaging/debian/changelog >>$(BUILD_DIR)/$(obspackage)/debian.changelog
	tar -xOzf dist/$(name)-$(distversion).tar.gz -C $(BUILD_DIR)/$(obspackage) $(name)-$(distversion)/packaging/debian/compat >>$(BUILD_DIR)/$(obspackage)/debian.compat
	tar -xOzf dist/$(name)-$(distversion).tar.gz -C $(BUILD_DIR)/$(obspackage) $(name)-$(distversion)/packaging/debian/copyright >>$(BUILD_DIR)/$(obspackage)/debian.copyright
	cd $(BUILD_DIR)/$(obspackage); osc addremove
	cd $(BUILD_DIR)/$(obspackage); osc ci -m "Update to $(name)-$(distversion)" $(BUILD_DIR)/$(obspackage)
	rm -rf $(BUILD_DIR)
	@echo -e "\033[1mNow visit https://build.opensuse.org/package/show?package=rear&project=$(obsproject)"
	@echo -e "or inspect the queue at: https://build.opensuse.org/monitor\033[0;0m"
else
	@echo -e "OBS already updated to this release."
endif
