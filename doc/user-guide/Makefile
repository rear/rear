prefix = /usr
datadir = $(prefix)/share
mandir = $(datadir)/man

adoctargets = relax-and-recover-user-guide.asciidoc
htmltargets = $(patsubst %.asciidoc, %.html, $(adoctargets))

all: docs

dist: docs

docs: $(htmltargets)

clean:
	rm -f *.html *.svg *.xml

%.html: %.asciidoc
	asciidoc $<
