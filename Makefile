.PHONY: help all test clean install installdeps

help:
	@echo
	@echo "Build application binaries:"
	@echo "  make all"
	@echo
	@echo "Basic application tests:"
	@echo "  make test"
	@echo
	@echo "Clean up build/test products:"
	@echo "  make clean"
	@echo
	@echo "Install (only works from a release directory):"
	@echo "  make install"
	@echo

all: Build README.md

README.md: lib/UIC/DBIx/Class/UserBasedAccess.pm
	pod2markdown lib/UIC/DBIx/Class/UserBasedAccess.pm >README.md

Build: Build.PL
	perl Build.PL

test: Build
	./Build test

clean: Build
	./Build realclean

commit: clean README.md
	git commit
	git push origin master

status: clean README.md
	git status

install: installdeps
	./Build install

installdeps: Build
	./Build installdeps
