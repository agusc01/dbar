PREFIX ?= /usr/local
CC ?= cc
LDFLAGS = -lX11

output: dbar.c config.def.h config.h
	${CC}  dbar.c $(LDFLAGS) -o dbar
config.h:
	cp config.def.h $@


clean:
	rm -f *.o *.gch dbar
install: output
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	install -m 0755 dbar $(DESTDIR)$(PREFIX)/bin/dbar
uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/dbar
