# @file    Makefile
# @brief   Makefile for steps in creating new releases on GitHub
# @date    2022-12-08
# @license Please see the file named LICENSE in the project directory
# @website https://github.com/caltechlibrary/iga
#
# ╭───────────────────────────── Important notes ─────────────────────────────╮
# │ Run "make" or "make help" to get a list of commands in this makefile.     │
# │                                                                           │
# │ The codemeta.json file is considered the master source for version and    │
# │ other info. Information is pulled out of codemeta.json to update other    │
# │ files like setup.cfg, the README, and others. Maintainers should update   │
# │ codemeta.json and not edit other files to update version numbers & URLs.  │
# │                                                                           │
# │ The parts involving the DOI in this makefile make 3 assumptions:          │
# │  * The DOI identifies the released version of this software by            │
# │    referencing a copy in a research data repository (RDM) system          │
# │  * The RDM server used is based on InvenioRDM (roughly same as Zenodo)    │
# │  * The codemeta.json file contains a "relatedLink" field whose value      │
# │    contains the URL of a copy of this software stored in the RDM server.  │
# │ With these assumptions, we can automatically get the latest DOI for a     │
# │ release in RDM (because given any release, RDM can be queried for the     │
# │ latest one) and we don't have to hardwire URLs or id's in this makefile.  │
# ╰───────────────────────────────────────────────────────────────────────────╯

SHELL=/bin/bash
.ONESHELL:                              # Run all commands in the same shell.
.SHELLFLAGS += -e                       # Exit at the first error.

# This Makefile uses syntax that needs at least GNU Make version 3.82.
# The following test is based on the approach posted by Eldar Abusalimov to
# Stack Overflow in 2012 at https://stackoverflow.com/a/12231321/743730

ifeq ($(filter undefine,$(value .FEATURES)),)
$(error Unsupported version of Make. \
    This Makefile does not work properly with GNU Make $(MAKE_VERSION); \
    it needs GNU Make version 3.82 or later)
endif

# Before we go any further, test if certain programs are available.
# The following is based on the approach posted by Jonathan Ben-Avraham to
# Stack Overflow in 2014 at https://stackoverflow.com/a/25668869

programs_needed = awk curl gh git jq sed python3
TEST := $(foreach p,$(programs_needed),\
	  $(if $(shell which $(p)),_,$(error Cannot find program "$(p)")))

# Set some basic variables. These are quick to set; we set additional ones
# using the dependency named "vars" but only when the others are needed.

name	 := $(strip $(shell jq -r .name codemeta.json))
progname := $(strip $(shell jq -r '.identifier | ascii_downcase' codemeta.json))
version	 := $(strip $(shell jq -r .version codemeta.json))
repo	 := $(shell git ls-remote --get-url | sed -e 's/.*:\(.*\).git/\1/')
repo_url := https://github.com/$(repo)
branch	 := $(shell git rev-parse --abbrev-ref HEAD)
initfile := $(progname)/__init__.py
distdir  := dist
builddir := build
today	 := $(shell date "+%F")

# Print help if no command is given ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# The help scheme works by looking for lines beginning with "#:" above make
# targets in this file. Originally based on code posted to Stack Overflow on
# 2019-11-28 by Richard Kiefer at https://stackoverflow.com/a/59087509/743730

#: Print a summary of available commands.
help:
	@echo "This is the Makefile for $(bright)$(name)$(reset)."
	@echo "Available commands:"
	@echo
	@grep -B1 -E "^[a-zA-Z0-9_-]+\:([^\=]|$$)" $(MAKEFILE_LIST) \
	| grep -v -- -- \
	| sed 'N;s/\n/###/' \
	| sed -n 's/^#: \(.*\)###\(.*\):.*/$(color)\2$(reset):###\1/p' \
	| column -t -s '###'

#: Summarize how to do a release using this makefile.
instructions:;
	@$(info $(instructions_text))

define instructions_text =
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ Steps for doing a release                                       ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
 1. Run $(color)make lint$(reset), fix any problems, and commit any changes.
 2. Run $(color)make tests$(reset) fix any problems, and commit any changes.
 3. Update the version number in codemeta.json.
 4. Check the output of $(color)make report$(reset) (ignoring current id & DOI).
 5. Run $(color)make really-clean$(reset).
 6. Run $(color)make packages$(reset) and fix any problems.
 7. Check CHANGES.md, update if needed, and commit changes.
 8. Run $(color)make release$(reset); after some steps, it will open a file
    in your editor to write GitHub release notes. Copy the notes
    from CHANGES.md. Save the opened file to finish the process.
 9. Check that everything looks okay with the GitHub release at
    $(link)$(repo_url)/releases$(reset)
10. Wait for IGA to finish running its GitHub action at
    $(link)$(repo_url)/actions$(reset)
11. Run $(color)make post-release$(reset).
endef


# Gather additional values we sometimes need ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# These variables take longer to compute, and for some actions like "make help"
# they are unnecessary and annoying to wait for.
vars:;
	$(eval url     := $(strip $(shell jq -r .url codemeta.json)))
	$(eval license := $(strip $(shell jq -r .license codemeta.json)))
	$(eval desc    := $(strip $(shell jq -r .description codemeta.json)))
	$(eval author  := \
	  $(strip $(shell jq -r '.author[0].givenName + " " + .author[0].familyName' codemeta.json)))
	$(eval email   := $(strip $(shell jq -r .author[0].email codemeta.json)))
	$(eval related := \
	  $(strip $(shell jq -r '.relatedLink | if type == "array" then .[0] else . end' codemeta.json)))
	$(eval rdm_url	  := $(shell cut -d'/' -f 1-3 <<< $(related)))
	$(eval current_id := $(shell sed -r 's|.*/(.*)$$|\1|' <<< $(related)))
	$(eval vers_url	  := $(rdm_url)/api/records/$(current_id)/versions)
	$(eval latest_doi := $(shell curl -s $(vers_url) | jq -r .hits.hits[0].pids.doi.identifier))

#: Print variables set in this Makefile from various sources.
report: vars
	@echo "$(color)name$(reset)	  = $(name)"	   | expand -t 20
	@echo "$(color)progname$(reset)   = $(progname)"   | expand -t 20
	@echo "$(color)desc$(reset)	  = $(desc)"	   | expand -t 20
	@echo "$(color)version$(reset)	  = $(version)"	   | expand -t 20
	@echo "$(color)author$(reset)	  = $(author)"	   | expand -t 20
	@echo "$(color)email$(reset)	  = $(email)"	   | expand -t 20
	@echo "$(color)license$(reset)	  = $(license)"	   | expand -t 20
	@echo "$(color)main url$(reset)   = $(url)"	   | expand -t 20
	@echo "$(color)repo url$(reset)   = $(repo_url)"   | expand -t 20
	@echo "$(color)branch$(reset)	  = $(branch)"	   | expand -t 20
	@echo "$(color)initfile$(reset)   = $(initfile)"   | expand -t 20
	@echo "$(color)distdir$(reset)	  = $(distdir)"	   | expand -t 20
	@echo "$(color)builddir$(reset)   = $(builddir)"   | expand -t 20
	@echo "$(color)current_id$(reset) = $(current_id)" | expand -t 20
	@echo "$(color)latest_doi$(reset) = $(latest_doi)" | expand -t 20


# make lint & make test ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#: Run the code through Python linters like flake8.
lint:
	flake8 iga


#: Run unit tests and coverage tests.
tests:;
	pytest -v --cov=iga -l tests/


# make install ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#: Install this program locally in dev mode using pip.
install:
	python3 -m pip install -e .[dev]


# make release ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#: Make a release on GitHub.
release: | test-branch confirm-release release-on-github wait-on-iga print-next

test-branch:
ifneq ($(branch),main)
	$(error Current git branch != main. Merge changes into main first!)
endif

confirm-release:
	@read -p "Have you updated the version number? [y/N] " ans && : $${ans:=N} ;\
	if [ $${ans::1} != y ]; then \
	  echo ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
	  echo ┃ Update the version number in codemeta.json first. ┃
	  echo ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
	  exit 1
	fi

update-all: update-init update-meta update-citation update-example

update-init: vars;
	@sed -i .bak -e "s|^\(__version__ *=\).*|\1 '$(version)'|"  $(initfile)
	@sed -i .bak -e "s|^\(__description__ *=\).*|\1 '$(desc)'|" $(initfile)
	@sed -i .bak -e "s|^\(__url__ *=\).*|\1 '$(url)'|"	    $(initfile)
	@sed -i .bak -e "s|^\(__author__ *=\).*|\1 '$(author)'|"    $(initfile)
	@sed -i .bak -e "s|^\(__email__ *=\).*|\1 '$(email)'|"	    $(initfile)
	@sed -i .bak -e "s|^\(__license__ *=\).*|\1 '$(license)'|"  $(initfile)

update-meta:
	@sed -i .bak -e '/"softwareVersion"/ s|: ".*"|: "$(version)"|' codemeta.json
	@sed -i .bak -e '/"datePublished"/ s|: ".*"|: "$(today)"|' codemeta.json

update-citation:
	@sed -i .bak -e '/^url:/ s|".*"|"$(url)"|' CITATION.cff
	@sed -i .bak -e '/^title:/ s|".*"|"$(name)"|' CITATION.cff
	@sed -i .bak -e '/^version:/ s|".*"|"$(version)"|' CITATION.cff
	@sed -i .bak -e '/^abstract:/ s|".*"|"$(desc)"|' CITATION.cff
	@sed -i .bak -e '/^license-url:/ s|".*"|"$(license)"|' CITATION.cff
	@sed -i .bak -e '/^date-released:/ s|".*"|"$(today)"|' CITATION.cff
	@sed -i .bak -e '/^repository-code:/ s|".*"|"$(repo_url)"|' CITATION.cff

update-example:
	@sed -i .bak -E -e "/.* version [0-9].[0-9]+.[0-9]+/ s/[0-9].[0-9]+.[0-9]+/$(version)/" sample-workflow.yml

edited := codemeta.json $(initfile) CITATION.cff sample-workflow.yml

commit-updates:
	git add $(edited)
	git diff-index --quiet HEAD $(edited) || \
	    git commit -m"chore: update stored version number" $(edited)

release-on-github: | update-all commit-updates
	$(eval tmp_file := $(shell mktemp /tmp/release-notes-$(progname).XXXX))
	$(eval tag := "v$(shell tr -d '()' <<< "$(version)" | tr ' ' '-')")
	git push -v --all
	git push -v --tags
	@$(info ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓)
	@$(info ┃ Write release notes in the file that gets opened in your  ┃)
	@$(info ┃ editor. Close the editor to complete the release process. ┃)
	@$(info ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛)
	sleep 2
	$(EDITOR) $(tmp_file)
	gh release create $(tag) -t "Release $(version)" -F $(tmp_file)

wait-on-iga:
	@$(info ┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓)
	@$(info ┃ Wait for the archiving workflow to finish on GitHub ┃)
	@$(info ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛)
	sleep 2
	$(eval pid := $(shell gh run list --workflow=iga.yml --limit 1 | tail -1 | awk -F $'\t' '{print $7}'))
	$(shell gh run watch $pid)

print-next-steps: vars
	@$(info ┏━━━━━━━━━━━━┓)
	@$(info ┃ Next steps ┃)
	@$(info ┗━━━━━━━━━━━━┛)
	@$(info  Next steps:
	@$(info  1. Check $(repo_url)/releases )
	@$(info  2. Run "make update-doi" to update the DOI in README.md
	@$(info  3. Run "make packages" and check the results
	@$(info  4. Run "make test-pypi" to push to test.pypi.org
	@$(info  5. Check https://test.pypi.org/project/$(progname) )
	@$(info  6. Run "make pypi" to push to pypi for real

#: Update values in CITATION.cff, codemeta.json, and README.md.
post-release: update-doi update-relatedlink

update-doi: vars
	$(eval doi_tail := $(shell cut -f'2' -d'/' <<< $(latest_doi)))
	sed -i .bak -e '/doi:/ s|doi: .*|doi: $(latest_doi)|' CITATION.cff
	sed -i .bak -E -e 's|records/[[:alnum:]]{5}-[[:alnum:]]{5}|records/$(doi_tail)|g' README.md
	git add CITATION.cff README.md
	git diff-index --quiet HEAD CITATION.cff README.md || \
	  (git commit -m"chore: update DOI" CITATION.cff README.md && \
	   git push -v --all)

update-relatedlink: vars
	$(eval new_id   := $(shell cut -f'2' -d'/' <<< $(latest_doi)))
	$(eval new_link := $(rdm_url)/records/$(new_id))
	@sed -i .bak -e '/"relatedLink"/ s|: ".*"|: "$(new_link)"|' codemeta.json
	git add codemeta.json
	git diff-index --quiet HEAD codemeta.json || \
	  (git commit -m"chore: update links" codemeta.json && git push -v --all)

#: Create the distribution files for PyPI.
packages: | clean
	-mkdir -p $(builddir) $(distdir)
	python3 setup.py sdist --dist-dir $(distdir)
	python3 setup.py bdist_wheel --dist-dir $(distdir)
	python3 -m twine check $(distdir)/$(progname)-$(version).tar.gz

# Note: for the next action to work, the repository "testpypi" needs to be
# defined in your ~/.pypirc file. Here is an example file:
#
#  [distutils]
#  index-servers =
#    pypi
#    testpypi
#
#  [testpypi]
#  repository = https://test.pypi.org/legacy/
#  username = YourPyPIlogin
#  password = YourPyPIpassword
#
# You could copy-paste the above to ~/.pypirc, substitute your user name and
# password, and things should work after that. See the following for more info:
# https://packaging.python.org/en/latest/specifications/pypirc/

#: Upload distribution to test.pypi.org.
test-pypi: packages
	python3 -m twine upload --verbose --repository testpypi \
	   $(distdir)/$(progname)-$(version)*.{whl,gz}

#: Upload distribution to pypi.org.
pypi: packages
	python3 -m twine upload $(distdir)/$(progname)-$(version)*.{gz,whl}


# Cleanup ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#: Clean this directory of temporary and backup files.
clean: clean-dist clean-build clean-release clean-other
	@echo ✨ Cleaned! ✨

clean-release:;
	rm -rf $(progname).egg-info codemeta.json.bak $(initfile).bak README.md.bak

clean-other:;
	rm -fr __pycache__ $(progname)/__pycache__ .eggs
	rm -rf .cache
	rm -rf .pytest_cache
	rm -f *.bak
	rm -f tests/*.log

#: Like "make clean", and also remove build/ and dist/.
really-clean: clean
	rm -rf dist build
	rm -rf $(builddir)


# Miscellaneous directives ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#: Print a random joke from https://icanhazdadjoke.com/.
joke:
	@echo "$(shell curl -s https://icanhazdadjoke.com/)"

# Color codes used in messages.
color  := $(shell tput bold; tput setaf 6)
bright := $(shell tput bold; tput setaf 15)
dim    := $(shell tput setaf 66)
link   := $(shell tput setaf 111)
reset  := $(shell tput sgr0)

.PHONY: help vars report release test-branch test tests update-all \
	update-init update-meta update-citation update-example commit-updates \
	release-on-github print-instructions update-doi \
	packages test-pypi pypi clean really-clean completely-clean \
	clean-dist really-clean-dist clean-build really-clean-build \
	clean-release clean-other

.SILENT: clean clean-dist clean-build clean-release clean-other really-clean \
	really-clean-dist really-clean-build completely-clean vars
