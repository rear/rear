# In some dists (e.g. Ubuntu) bash is not the default shell. Statements like
#   cp -a etc/rear/{mappings,templates} ...
# assumes bash. So its better to set SHELL
SHELL = /bin/bash

# disable parallel execution of make
.NOTPARALLEL:

DESTDIR =
OFFICIAL =
DIST_CONTENT = COPYING  doc  etc  MAINTAINERS  Makefile  packaging  README.adoc  tests  tools  usr

### Get version from Relax-and-Recover itself
rearbin = usr/sbin/rear
name = rear
version := $(shell awk 'BEGIN { FS="=" } /^readonly VERSION=/ { print $$2}' $(rearbin))

BUILD_DIR = /var/tmp/build-$(name)-$(version)

ifneq ($(OFFICIAL),)
	distversion = $(version)
	debrelease = 0
	rpmrelease = %nil
	obsproject = Archiving:Backup:Rear
	obspackage = $(name)-$(version)

	date := $(shell date +%Y%m%d%H%M)
	release_date := $(shell date +%Y-%m-%d)
else
# Not official build, so we need to get the git info
# Some distros have older git, hence we need to do more processing
# of the output to get the exact same output on all the distros
	ifneq ($(wildcard .git),)
		ifneq ($(shell type -p git),)
			git_date := $(shell git log -n 1 --format="%ai")
			git_ref := $(shell git rev-parse HEAD | cut -c 1-8)
			git_count := $(shell git rev-list HEAD --no-merges | wc -l)
			git_branch_suffix = $(shell git symbolic-ref HEAD | sed -e 's,^.*/,,' -e "s/[^A-Za-z0-9]//g")
			git_status := $(shell git status --porcelain)
			git_stamp := $(git_count).$(git_ref).$(git_branch_suffix)
			ifneq ($(git_status),)
				git_stamp := $(git_stamp).changed
			endif # git_status
		else # no git
			git_date := now
			git_ref := 0
			git_count := 0
			git_branch_suffix := unknown
			git_stamp := $(git_count).$(git_ref).$(git_branch_suffix)
		endif # has git
	endif # has .git
	git_stamp ?= 0.0.unknown

    distversion = $(version)-git.$(git_stamp)
    debrelease = 0git.$(git_stamp)
    rpmrelease = .git.$(git_stamp)
    obsproject = Archiving:Backup:Rear:Snapshot
    obspackage = $(name)

	date := $(shell date --date="$(git_date)" +%Y%m%d%H%M)
	release_date := $(shell date --date="$(git_date)" +%Y-%m-%d)
endif


prefix = /usr
sysconfdir = /etc
sbindir = $(prefix)/sbin
datadir = $(prefix)/share
mandir = $(datadir)/man
localstatedir = /var

specfile = packaging/rpm/$(name).spec
dscfile = packaging/debian/$(name).dsc

# Spec file that will be actually used to build the package
# - a bit modified from the source $(specfile)
effectivespecfile = $(name)-$(distversion)/$(specfile)

rpmdefines =    --define="_topdir $(BUILD_DIR)/rpmbuild" \
		--define="rpmrelease $(rpmrelease)" \
		--define="debug_package %{nil}"

ifeq ($(shell id -u),0)
RUNASUSER := runuser -u nobody --
else
RUNASUSER :=
endif

tarparams = --exclude-from=.gitignore --exclude=.gitignore --exclude=".??*" $(DIST_CONTENT)

DIST_FILES := $(shell tar -cv -f /dev/null $(tarparams))

.PHONY: doc dump package

all:
	@echo "Nothing to build. Use 'make help' for more information."

help:
	@echo -e "Relax-and-Recover make targets:\n\
\n\
  validate        - Check source code\n\
  install         - Install Relax-and-Recover (may replace files)\n\
  uninstall       - Uninstall Relax-and-Recover (may remove files)\n\
  dist            - Create tar file in dist/\n\
  dist-install    - Create tar file in dist and use that to install via make install\n\
                    We use this to install from checkout with correct version\n\
  package         - Create DEB/PM/Pacman package in dist/\n\
  deb             - Create DEB package in dist/\n\
  rpm             - Create RPM package in dist/\n\
  pacman          - Create Pacman package\n\
  obs             - Initiate OBS builds\n\
  dump            - Dump Makefile variables\n\
\n\
Relax-and-Recover make variables (optional):\n\
\n\
  DESTDIR=        - Location to install/uninstall\n\
  OFFICIAL=1      - Build an official release\n\
  \n\
"

dump:
# found at https://www.cmcrossroads.com/article/dumping-every-makefile-variable
	$(foreach V, $(sort $(.VARIABLES)), $(if $(filter-out environment% default automatic, $(origin $V)),$(info $V=$($V) defined as >$(value $V)<)))

clean:
	rm -Rf dist $(BUILD_DIR) etc/os.conf etc/site.conf var build-stamp
	$(MAKE) -C doc clean

### You can call 'make validate' directly from your .git/hooks/pre-commit script
validate:
	@echo -e "\033[1m== Validating scripts and configuration ==\033[0;0m"
	find etc/ usr/share/rear/conf/ -name '*.conf' | xargs -n 1 $(SHELL) -n
	$(SHELL) -n $(rearbin)
	find . -name '*.sh' | xargs -n 1 $(SHELL) -O extglob -O nullglob -n
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
	$(MAKE) -C doc man

doc:
	@echo -e "\033[1m== Prepare documentation ==\033[0;0m"
	$(MAKE) -C doc docs

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
		-e 's,^LOG_DIR=.*,LOG_DIR="$(localstatedir)/log/rear",' \
		$(DESTDIR)$(sbindir)/rear

install-data:
	@echo -e "\033[1m== Installing scripts ==\033[0;0m"
	rm -Rf $(DESTDIR)$(datadir)/rear
	install -d -m0755 $(DESTDIR)$(datadir)/rear/
	cp -a usr/share/rear/. $(DESTDIR)$(datadir)/rear/
	-find $(DESTDIR)$(datadir)/rear/ -name '.gitignore' -exec rm -rf {} \; &>/dev/null

install-var:
	@echo -e "\033[1m== Installing working directory ==\033[0;0m"
	install -d -m0755 $(DESTDIR)$(localstatedir)/lib/rear/
	install -d -m0755 $(DESTDIR)$(localstatedir)/log/rear/

install-doc:
	@echo -e "\033[1m== Installing documentation ==\033[0;0m"
	$(MAKE) -C doc install
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

# most of the sed stuff should be skipped if $(distversion) == $(version)
# except RELEASE_DATE= and perhaps the Version in $(dscfile)
dist/$(name)-$(distversion).tar.gz: $(DIST_FILES)
	@echo -e "\033[1m== Building archive $(name)-$(distversion) ==\033[0;0m"
	rm -Rf $(BUILD_DIR)/$(name)-$(distversion)
	mkdir -p dist $(BUILD_DIR)/$(name)-$(distversion)
	tar -c $(tarparams) | tar -C $(BUILD_DIR)/$(name)-$(distversion) -x
	@echo -e "\033[1m== Rewriting $(BUILD_DIR)/$(name)-$(distversion)/{$(specfile),$(dscfile),$(rearbin)} ==\033[0;0m"
	sed -i \
		-e 's#^Source:.*#Source: $(name)-${distversion}.tar.gz#' \
		-e 's#^Version:.*#Version: $(version)#' \
		-e 's#^%setup.*#%setup -q -n $(name)-$(distversion)#' \
		$(BUILD_DIR)/$(effectivespecfile)
	sed -i \
		-e 's#^Version:.*#Version: $(version)-$(debrelease)#' \
		$(BUILD_DIR)/$(name)-$(distversion)/$(dscfile)
	sed -i \
		-e 's#^readonly VERSION=.*#readonly VERSION=$(distversion)#' \
		-e 's#^readonly RELEASE_DATE=.*#readonly RELEASE_DATE="$(release_date)"#' \
		$(BUILD_DIR)/$(name)-$(distversion)/$(rearbin)
	tar -czf dist/$(name)-$(distversion).tar.gz -C $(BUILD_DIR) $(name)-$(distversion)

# make install from dist tarball, to get a clean install without any build artifacts
dist-install: dist/$(name)-$(distversion).tar.gz
	mkdir -p $(BUILD_DIR)/dist-install
	tar -C $(BUILD_DIR)/dist-install -xvzf dist/$(name)-$(distversion).tar.gz --strip-components 1
	$(MAKE) -C $(BUILD_DIR)/dist-install install

package-clean:
	rm -f dist/*.rpm dist/*.deb dist/*.pkg.*

ifneq ($(shell type -p pacman),)
package: package-clean pacman
else ifneq ($(shell type -p dpkg),)
package: package-clean deb
else ifneq ($(shell type -p rpm),)
package: package-clean rpm
else
package:
	$(error Cannot determine package manager)
endif

# Note, older rpm checks file ownership, so we copy dist tarball to build dir first for Docker builds
srpm: dist/$(name)-$(distversion).tar.gz
	@echo -e "\033[1m== Building SRPM package $(name)-$(distversion) ==\033[0;0m"
	if test "$(savedspecfile)"; then tar -xzOf dist/$(name)-$(distversion).tar.gz $(effectivespecfile) > "$(savedspecfile)"; fi
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	cp dist/$(name)-$(distversion).tar.gz $(BUILD_DIR)/
	rpmbuild -ts --clean --nodeps \
		--define="_sourcedir $(CURDIR)/dist" \
		--define="_srcrpmdir $(CURDIR)/dist" \
		$(rpmdefines) \
		$(BUILD_DIR)/$(name)-$(distversion).tar.gz

# Temporary file passed to 'srpm', where the spec file will be available
# even after removing BUILD_DIR
rpm: savedspecfile := $(shell mktemp --suffix .spec)
# uniq because if we ever use subpackages, there will be multiple identical lines, one per each subpackage
# the rpmspec tool with --srpm would be preferable - it queries the source RPM information,
# but unfortunately it does not exist yet on EL6.
rpm: NEVR = $(name)-$(shell rpm -q $(rpmdefines) --queryformat '%{EVR}' --specfile "$(savedspecfile)" | uniq)
rpm: srpm
	@echo -e "\033[1m== Building RPM package $(NEVR) ==\033[0;0m"
	rpmbuild --rebuild --clean \
		--define="_rpmdir $(CURDIR)/dist" \
		--define "_rpmfilename %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm" \
		$(rpmdefines) \
		dist/$(NEVR).src.rpm
	rm -f $(savedspecfile)

deb: dist/$(name)-$(distversion).tar.gz
	@echo -e "\033[1m== Building DEB package $(name)-$(distversion) ==\033[0;0m"
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	tar -C $(BUILD_DIR) -xzf dist/$(name)-$(distversion).tar.gz
	cd $(BUILD_DIR)/$(name)-$(distversion) ; mv packaging/debian/ .
	cd $(BUILD_DIR)/$(name)-$(distversion) ; dch -v $(distversion) -b -M $(BUILD_DIR) package
	cd $(BUILD_DIR)/$(name)-$(distversion) ; debuild -us -uc -i -b --lintian-opts --profile debian
	mv $(BUILD_DIR)/$(name)_*.deb dist/

pacman: BUILD_DIR = /tmp/rear-$(distversion)
pacman: dist/$(name)-$(distversion).tar.gz
	@echo -e "\033[1m== Building Pacman package $(name)-$(distversion) ==\033[0;0m"
	rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	cp packaging/arch/PKGBUILD.local $(BUILD_DIR)/PKGBUILD
	cp dist/$(name)-$(distversion).tar.gz $(BUILD_DIR)/
	cd $(BUILD_DIR) ; \
		sed -i -e 's/VERSION/$(date)/' \
			-e 's/SOURCE/$(name)-$(distversion).tar.gz/' \
			-e 's/MD5SUM/$(shell md5sum dist/$(name)-$(distversion).tar.gz | cut -d' ' -f1)/' \
			PKGBUILD ; \
		chmod -R o+rwX . ; ls -l ; \
		$(RUNASUSER) makepkg -c
	cp $(BUILD_DIR)/*.pkg.* dist/
	rm -rf $(BUILD_DIR)

obs: BUILD_DIR = /tmp/rear-$(distversion)
obs: obsname = $(shell osc ls $(obsproject) $(obspackage) | awk '/.tar.gz$$/ { gsub(".tar.gz$$","",$$1); print }')
obs: dist/$(name)-$(distversion).tar.gz
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
