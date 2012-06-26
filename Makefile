### Get version from Relax-and-Recover itself
rearbin = usr/sbin/rear
name = rear
version := $(shell awk 'BEGIN { FS="=" } /^VERSION=/ { print $$2}' $(rearbin))

### Get the branch information from git
git_date := $(shell git log -n 1 --format="%ai")
git_ref := $(shell git symbolic-ref -q HEAD)
git_branch ?= $(lastword $(subst /, ,$(git_ref)))
git_branch ?= HEAD

date := $(shell date --date="$(git_date)" +%Y%m%d%H%M)
release_date := $(shell date --date="$(git_date)" +%Y-%m-%d)

prefix = /usr
sysconfdir = /etc
sbindir = $(prefix)/sbin
datadir = $(prefix)/share
mandir = $(datadir)/man
localstatedir = /var

specfile = contrib/$(name).spec

DESTDIR =
OFFICIAL =

distversion = $(version)
rpmrelease =
obsproject = Archiving:Backup:Rear
obspackage = $(name)
ifeq ($(OFFICIAL),)
    distversion = $(version)-git$(date)
    rpmrelease = .git$(date)
    obsproject = Archiving:Backup:Rear:Snapshot
endif

.PHONY: doc

all:
	@echo "Nothing to build. Use \`make help' for more information."

help:
	@echo -e "Relax-and-Recover make targets:\n\
\n\
  validate        - Check source code\n\
  install         - Install Relax-and-Recover to DESTDIR (may replace files)\n\
  uninstall       - Uninstall Relax-and-Recover from DESTDIR (may remove files)\n\
  dist            - Create tar file\n\
  deb             - Create DEB package\n\
  rpm             - Create RPM package\n\
\n\
Relax-and-Recover make variables (optional):\n\
\n\
  DESTDIR=        - Location to install/uninstall\n\
  OFFICIAL=       - Build an official release\n\
"

clean:

### You can call 'make validate' directly from your .git/hooks/pre-commit script
validate:
	@echo -e "\033[1m== Validating scripts and configuration ==\033[0;0m"
	find etc/ usr/share/rear/conf/ -name '*.conf' | xargs bash -n
	bash -n $(rearbin)
	find . -name '*.sh' | xargs bash -n
### Fails to work on RHEL
#	find -L . -type l

man:
	@echo -e "\033[1m== Prepare manual ==\033[0;0m"
	make -C doc man

doc:
	@echo -e "\033[1m== Prepare documentation ==\033[0;0m"
	make -C doc docs

ifneq ($(git_date),)
rewrite:
	@echo -e "\033[1m== Rewriting $(specfile) and $(rearbin) ==\033[0;0m"
	sed -i.orig \
		-e 's#^Source:.*#Source: $(name)-$(distversion).tar.bz2#' \
		-e 's#^Version:.*#Version: $(version)#' \
		-e 's#^%define rpmrelease.*#%define rpmrelease $(rpmrelease)#' \
		$(specfile)
	sed -i.orig \
		-e 's#^VERSION=.*#VERSION=$(distversion)#' \
		-e 's#^RELEASE_DATE=.*#RELEASE_DATE="$(release_date)"#' \
		$(rearbin)

restore:
	@echo -e "\033[1m== Restoring $(specfile) and $(rearbin) ==\033[0;0m"
	mv $(specfile).orig $(specfile)
	mv $(rearbin).orig $(rearbin)
else
rewrite:
	@echo "Nothing to do."

restore:
	@echo "Nothing to do."
endif

install-config:
	@echo -e "\033[1m== Installing configuration ==\033[0;0m"
	install -d -m0700 $(DESTDIR)$(sysconfdir)/rear/
	-[[ ! -e $(DESTDIR)$(sysconfdir)/rear/local.conf ]] && \
		install -Dp -m0600 etc/rear/local.conf $(DESTDIR)$(sysconfdir)/rear/local.conf
	cp -a etc/rear/{mappings,templates} $(DESTDIR)$(sysconfdir)/rear/
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

install: validate man install-config rewrite install-bin restore install-data install-var install-doc

uninstall:
	@echo -e "\033[1m== Uninstalling Relax-and-Recover ==\033[0;0m"
	-rm -v $(DESTDIR)$(sbindir)/rear
	-rm -v $(DESTDIR)$(mandir)/man8/rear.8
	-rm -rv $(DESTDIR)$(datadir)/rear/
#	rm -rv $(DESTDIR)$(sysconfdir)/rear/
#	rm -rv $(DESTDIR)$(localstatedir)/lib/rear/

dist: clean validate man rewrite $(name)-$(distversion).tar.bz2 restore

$(name)-$(distversion).tar.bz2:
	@echo -e "\033[1m== Building archive $(name)-$(distversion) ==\033[0;0m"
	git ls-tree -r --name-only --full-tree $(git_branch) | \
		tar -cjf $(name)-$(distversion).tar.bz2 --transform='s,^,$(name)-$(version)/,S' --files-from=-

rpm: dist
	@echo -e "\033[1m== Building RPM package $(name)-$(distversion)==\033[0;0m"
	rpmbuild -tb --clean \
		--define "_rpmfilename %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm" \
		--define "debug_package %{nil}" \
		--define "_rpmdir %(pwd)" $(name)-$(distversion).tar.bz2

obs: BUILD_DIR = /tmp/rear-$(distversion)
obs: obsname = $(shell osc ls $(obsproject) $(obspackage) | awk '/.tar.bz2$$/ { gsub(".tar.bz2$$","",$$1); print }')
obs: dist
	@echo -e "\033[1m== Updating OBS from $(obsname) to $(name)-$(distversion)==\033[0;0m"
ifneq ($(obsname),$(name)-$(distversion))
	-rm -rf $(BUILD_DIR)
	mkdir -p $(BUILD_DIR)
	osc co -c $(obsproject) $(obspackage) -o $(BUILD_DIR)
	-osc del $(BUILD_DIR)/*.tar.bz2
	cp $(name)-$(distversion).tar.bz2 $(BUILD_DIR)
	tar -xOjf $(name)-$(distversion).tar.bz2 -C $(BUILD_DIR) $(name)-$(version)/$(specfile) >$(BUILD_DIR)/$(name).spec
	osc add $(BUILD_DIR)/$(name)-$(distversion).tar.bz2
	osc ci -m "Update to $(name)-$(distversion)" $(BUILD_DIR)
	rm -rf $(BUILD_DIR)
endif
