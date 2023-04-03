SHELL=/bin/bash

# disable parallel execution of make
.NOTPARALLEL:

prefix = /usr
datadir = $(prefix)/share
mandir = $(datadir)/man

adoctargets = relax-and-recover-user-guide.adoc
htmltargets = $(patsubst %.adoc, %.html, $(adoctargets))

asciidoc := $(shell if type -p asciidoctor >/dev/null; then echo asciidoctor; else echo asciidoc; fi)

all: docs

dist: docs

docs: $(htmltargets)

clean:
	rm -f *.html *.svg *.xml

%.html: %.adoc
	$(asciidoc) -a footer-style=none $<
