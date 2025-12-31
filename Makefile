.PHONY:  install uninstall test clean help

PREFIX ? = /usr/local
BINDIR ? = $(PREFIX)/bin
MANDIR ?= $(PREFIX)/share/man/man1

help:
	@echo "ArchMode - Makefile targets:"
	@echo "  make install   - Install archmode"
	@echo "  make uninstall - Remove archmode"
	@echo "  make test      - Run tests"
	@echo "  make clean     - Clean up"

install:
	@echo "Installing ArchMode..."
	sudo install -Dm755 archmode.sh $(BINDIR)/archmode
	sudo install -Dm755 archmode.sh $(BINDIR)/am
	@echo "✓ Installation complete!"
	@echo "Run 'archmode' to start"

uninstall:
	@echo "Removing ArchMode..."
	sudo rm -f $(BINDIR)/archmode $(BINDIR)/am
	@echo "✓ Uninstalled"

test:
	@echo "Running basic tests..."
	bash -n archmode. sh
	@echo "✓ Syntax check passed"

clean:
	rm -rf *.tar.gz *.pkg.tar.zst
	@echo "✓ Cleaned up"
