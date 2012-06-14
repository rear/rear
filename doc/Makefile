prefix = /usr
datadir = $(prefix)/share
mandir = $(datadir)/man

txttargets = $(shell echo *.txt)
htmltargets = $(patsubst %.txt, %.html, $(txttargets))

all:

dist: docs

docs: rear.8 $(htmltargets)

install: rear.8
	install -Dp -m0644 rear.8 $(DESTDIR)$(mandir)/man8/rear.8

clean:
	rm -f unconv.8 *.html *.xml

%.1.html: %.1.txt
	asciidoc -d manpage $<

%.1: %.1.xml
	xmlto man $<

%.html: %.txt
	asciidoc $<

%.1.xml: %.1.txt
	asciidoc -b docbook -d manpage $<
