prefix = /usr
datadir = $(prefix)/share
mandir = $(datadir)/man
docdir = $(datadir)/doc/rear

txttargets = $(shell echo *.txt)
htmltargets = $(patsubst %.txt, %.html, $(txttargets))

all: docs

dist: docs

man: rear.8

docs: rear.8 $(htmltargets)
	make -C user-guide docs

install: docs
	install -Dp -m0644 rear.8 $(DESTDIR)$(mandir)/man8/rear.8
	install -d -m0755 $(DESTDIR)$(docdir)
	install -p -m0644 $(txttargets) $(DESTDIR)$(docdir)
	install -p -m0644 $(htmltargets) $(DESTDIR)$(docdir)
	-rm $(DESTDIR)$(docdir)/rear.8.txt $(DESTDIR)$(docdir)/rear.8.html
	make -C user-guide install

clean:
	make -C user-guide clean
	rm -f unconv.8 *.html *.xml

%.8.html: %.8.txt
	asciidoc -d manpage $<

%.8: %.8.xml
	xmlto man $<

%.html: %.txt
	asciidoc $<

%.8.xml: %.8.txt
	asciidoc -b docbook -d manpage $<
