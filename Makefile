name = rear
#version = $(shell awk '/^Version: / { print $$2}' $(name).spec)
version = $(shell awk 'BEGIN { FS="=" } /^VERSION=/ { print $$2}' usr/sbin/rear)

prefix = /usr
sysconfdir = /etc
sbindir = $(prefix)/sbin
datadir = $(prefix)/share
mandir = $(datadir)/man
localstatedir = /var

all:
	@echo "Nothing to be build."

clean:

uninstall:
	-rm -v $(DESTDIR)$(sbindir)/rear
	-rm -v $(DESTDIR)$(mandir)/man8/rear.8
	-rm -rv $(DESTDIR)$(datadir)/rear/
#	rm -rv $(DESTDIR)$(localstatedir)/lib/rear/

install:
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

dist: clean
	git ls-tree -r --name-only --full-tree $$(git branch --no-color 2>/dev/null | \
	sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/') | \
	pax -d -w -x ustar -s ,^,$(name)-$(version)/, | \
	bzip2 >$(name)-$(version).tar.bz2

rpm: dist
#	rpmbuild -tb --clean --rmspec --define "_rpmfilename %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm" --define "_rpmdir %(pwd)" $(name)-$(version).tar.bz2
	rpmbuild -bb --clean \
	--define "_rpmfilename %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm" \
	--define "_rpmdir %(pwd)" contrib/$(name).spec
