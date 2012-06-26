prefix = /usr
datadir = $(prefix)/share
mandir = $(datadir)/man

txttargets = relax-and-recover-user-guide.txt
htmltargets = $(patsubst %.txt, %.html, $(txttargets))

all: docs

dist: docs

docs: $(htmltargets)

clean:
	rm -f *.html *.svg *.xml

%.html: %.txt
	asciidoc $<
