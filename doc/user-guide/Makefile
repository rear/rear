prefix = /usr
datadir = $(prefix)/share
mandir = $(datadir)/man

adoctargets = relax-and-recover-user-guide.adoc
htmltargets = $(patsubst %.adoc, %.html, $(adoctargets))

all: docs

dist: docs

docs: $(htmltargets)

clean:
	rm -f *.html *.svg *.xml

%.html: %.adoc
	asciidoc -a footer-style=none $<
