SHELL=/bin/bash

# disable parallel execution of make
.NOTPARALLEL:

prefix = /usr
datadir = $(prefix)/share
mandir = $(datadir)/man

adoctargets = $(shell echo *.adoc)
htmltargets = $(patsubst %.adoc, %.html, $(adoctargets))

# asciidoctor is in Ruby and used on Debian and SUSE and can generate manpages directly
# asciidoc is in Python and used on Fedora and RHEL and cannot generate manpages, so we use xmlto to convert docbooc to manpage
asciidoc := $(shell if type -p asciidoctor >/dev/null; then echo asciidoctor; else echo asciidoc; fi)

all: docs

dist: docs

man: rear.8

docs: rear.8 $(htmltargets)
	make -C user-guide docs

install: rear.8
	install -Dp -m0644 rear.8 $(DESTDIR)$(mandir)/man8/rear.8

clean:
	rm -f unconv.8 *.html *.xml
	make -C user-guide clean

%.8.html: %.8.adoc
	$(asciidoc) -a footer-style=none -d manpage $<

ifeq ($(asciidoc),asciidoc)
%.8.xml: %.8.adoc
	$(asciidoc) -b docbook -d manpage $<

%.8: %.8.xml
	xmlto man $<
else
%.8: %.8.adoc
	$(asciidoc) -b manpage -d manpage $<
endif

%.html: %.adoc
	$(asciidoc) -a footer-style=none $<
