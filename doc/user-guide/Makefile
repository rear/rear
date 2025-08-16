SHELL=/bin/bash

# disable parallel execution of make
.NOTPARALLEL:

prefix = /usr
datadir = $(prefix)/share
mandir = $(datadir)/man

# ronn is a tool to generate man-pages directly from MarkDown files
ronn := $(shell if type -p ronn >/dev/null; then echo ronn; fi)
htmltarget = relax-and-recover-user-guide.html

all: docs

dist: docs

docs:
	@echo "Prepare ReaR User Guide"
	cat *.md | ronn --html > $(htmltarget)

clean:
	rm -f *.html
