prefix = /usr
datadir = $(prefix)/share
mandir = $(datadir)/man
docdir = $(datadir)/doc/rear

txttargets = relax-and-recover-user-guide.txt
htmltargets = $(patsubst %.txt, %.html, $(txttargets))

all: docs

dist: docs

docs: $(htmltargets)

install: docs
	install -d -m0755 $(DESTDIR)$(docdir)/user-guide
	install -p -m0644 *.txt $(DESTDIR)$(docdir)/user-guide
	install -p -m0644 $(htmltargets) $(DESTDIR)$(docdir)/user-guide

clean:
	rm -f *.html *.svg *.xml

%.html: %.txt
	asciidoc $<
