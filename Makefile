MAINTAINER=Johnathan Kupferer <jtk@uic.edu>
PROJNAME=UIC-DBIC
PROJTYPE=library
VERSION=trunk
DIST=`if [ -e /etc/redhat-release ]; then sed -r 's/.*release ([0-9]+).*/.el\1/' /etc/redhat-release; elif [ -e /etc/fedora-release ]; then sed -r 's/.*release ([0-9]+).*/.fc\1/' /etc/fedora-release; elif [ -e /etc/centos-release ]; then sed -r 's/.*release ([0-9]+).*/.el\1/' /etc/centos-release; fi`

.PHONY: help all test clean install

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

all: Build

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

install: Build
	./Build install
