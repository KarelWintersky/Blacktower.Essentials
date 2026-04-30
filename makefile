#!/usr/bin/make
PACKAGE_NAME  = blacktower.essentials

DEVELOPER_EMAIL = karel@wintersky.ru
DEVELOPER_NAME = "Karel Wintersky"

help:
	@perl -e '$(HELP_ACTION)' $(MAKEFILE_LIST)

install:  	##@system Install package. Don't run it manually!!!
#	install -d $(PATH_PROJECT)
#	cp -r public $(PATH_PROJECT)/
#	chmod -R -x+X $(PATH_PROJECT)/*
#	chmod 444 $(PATH_PROJECT)/public/*.html

update:		##@build Update project from GIT
	@echo Updating project from GIT
	git pull --no-rebase

build:	##@build Build DEB-package with gulp
	@echo Building project
	@dpkg-buildpackage -rfakeroot -uc -us --compression-level=9 --diff-ignore=node_modules --tar-ignore=node_modules
	@dh_clean

dchr:		##@development Publish release
	@dch --controlmaint --release --distribution unstable

dchv:		##@development Append release
	@export DEBEMAIL="$(DEVELOPER_EMAIL)" && \
	export DEBFULLNAME="$(DEVELOPER_NAME)" && \
	echo "$(YELLOW)------------------ Previous version header: ------------------$(GREEN)" && \
	head -n 3 debian/changelog && \
	echo "$(YELLOW)--------------------------------------------------------------$(RESET)" && \
	read -p "Next version: " VERSION && \
	dch --controlmaint -v $$VERSION

dchn:		##@development Initial create changelog file
	@export DEBEMAIL="$(DEVELOPER_EMAIL)" && \
	export DEBFULLNAME="$(DEVELOPER_NAME)" && \
	dch --create --package $(PACKAGE_NAME)

# ------------------------------------------------
# Add the following 'help' target to your makefile, add help text after each target name starting with '\#\#'
# A category can be added with @category
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
RESET  := $(shell tput -Txterm sgr0)
HELP_ACTION = \
	%help; while(<>) { push @{$$help{$$2 // 'options'}}, [$$1, $$3] if /^([a-zA-Z\-_]+)\s*:.*\#\#(?:@([a-zA-Z\-]+))?\s(.*)$$/ }; \
	print "usage: make [target]\n\n"; for (sort keys %help) { print "${WHITE}$$_:${RESET}\n"; \
	for (@{$$help{$$_}}) { $$sep = " " x (32 - length $$_->[0]); print "  ${YELLOW}$$_->[0]${RESET}$$sep${GREEN}$$_->[1]${RESET}\n"; }; \
	print "\n"; }

# -eof- #

