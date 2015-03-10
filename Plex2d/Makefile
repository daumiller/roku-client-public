#########################################################################
#
# Makefile Usage:
# > make
# > make test install    (PlexPass  release)
# > make ninja install   (PlexNinja release)
#
# Important Notes:
# To use the "install" and "remove" targets to install your
# application directly from the shell, you must do the following:
#
# 1) Make sure that you have the curl command line executable in your path
# 2) Set the variable ROKU_DEV_TARGET in your environment to the IP
#    address of your Roku box. (e.g. export ROKU_DEV_TARGET=192.168.1.1.
#    Set in your this variable in your shell startup (e.g. .bashrc)
##########################################################################
APPNAME = Plex
APPDEPS = manifest count_functions
ZIP_EXCLUDE = -x .git\* -x manifest.template -x \*.swp -x \*.DS_Store -x \*.py -x roku_screenshot.jpg
include ../app.mk

APPTITLE = $(APPNAME)Pass

num_functions := $(shell grep -ri --include=*.brs 'end \(function\|sub\)' . | wc -l | tr -d ' ')
timestamp := $(shell date +'%Y-%m-%d-%H:%M:%S')

.PHONY: manifest count_functions test ninja rel

test: APPTITLE = $(APPNAME)Pass
test: $(APPNAME)

ninja: APPTITLE = $(APPNAME)Ninja
ninja: $(APPNAME)

rel: APPTITLE = $(APPNAME)
rel: $(APPNAME)


manifest:
	$(eval LC_APPTITLE := $(shell tr '[A-Z]' '[a-z]' <<< $(APPTITLE)))
	echo "Creating manifest for $(APPTITLE)"
	sed 's/LC_APPTITLE/$(LC_APPTITLE)/;s/APPTITLE/$(APPTITLE)/' < manifest.template > manifest

count_functions:
	echo "Counting functions for $(APPTITLE), some Rokus limit to 65536"
	test $(num_functions) -le 65536

screenshot:
	$(CURL) -s -F passwd= -F mysubmit=Screenshot -F "archive=;filename=" -H "Expect:" "http://$(ROKU_DEV_TARGET)/plugin_inspect" > /dev/null
	$(CURL) -s "http://$(ROKU_DEV_TARGET)/pkgs/dev.jpg" > roku_screenshot-$(timestamp).jpg
	$(shell ln -fs roku_screenshot-$(timestamp).jpg roku_screenshot.jpg)

all: $(APPNAME)
