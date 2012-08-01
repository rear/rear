prefix = /usr
datadir = $(prefix)/share
mandir = $(datadir)/man

txttargets = $(shell echo *.txt)
htmltargets = $(patsubst %.txt, %.html, $(txttargets))

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

%.8.html: %.8.txt
	asciidoc -d manpage $<

%.8: %.8.xml
	xmlto man $<

%.html: %.txt
	asciidoc $<

%.8.xml: %.8.txt
	asciidoc -b docbook -d manpage $<
