prefix = /usr
datadir = $(prefix)/share
mandir = $(datadir)/man

adoctargets = $(shell echo *.adoc)
htmltargets = $(patsubst %.adoc, %.html, $(adoctargets))

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
	asciidoc -a footer-style=none -d manpage $<

%.8: %.8.xml
	xmlto man $<

%.html: %.adoc
	asciidoc -a footer-style=none $<

%.8.xml: %.8.adoc
	asciidoc -b docbook -d manpage $<
