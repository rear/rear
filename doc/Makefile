SHELL=/bin/bash

# disable parallel execution of make
.NOTPARALLEL:

prefix = /usr
datadir = $(prefix)/share
mandir = $(datadir)/man

ronn := $(shell if type -p ronn >/dev/null; then echo ronn; fi)

all: docs

dist: docs

man: rear.8

docs: rear.8
	make -C user-guide docs

install: rear.8
	install -Dp -m0644 rear.8 $(DESTDIR)$(mandir)/man8/rear.8

clean:
	rm -f *.8 *.html
	make -C user-guide clean

%.8: %.8.md
	$(ronn) --roff $<
