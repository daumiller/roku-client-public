#########################################################################
# common include file for application Makefiles
#
# Makefile Usage:
# > make
# > make install
# > make remove
#
# to exclude certain files from being added to the zipfile during packaging
# include a line like this:ZIP_EXCLUDE= -x keys\*
# that will exclude any file who's name begins with 'keys'
# to exclude using more than one pattern use additional '-x <pattern>' arguments
# ZIP_EXCLUDE= -x \*.pkg -x storeassets\*
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
PKGREL = ../packages
ZIPREL = ../zips
SOURCEREL = ..

ROKU_DEV_USERNAME ?= rokudev
ROKU_DEV_PASSWORD ?= plex
CURL = curl -v --anyauth -u $(ROKU_DEV_USERNAME):$(ROKU_DEV_PASSWORD) -H"Expect:"


.PHONY: all $(APPNAME)

$(APPNAME): $(APPDEPS)
	@echo "*** Creating $(APPNAME).zip ***"

	@echo "  >> removing old application zip $(ZIPREL)/$(APPNAME).zip"
	@if [ -e "$(ZIPREL)/$(APPNAME).zip" ]; \
	then \
		rm  $(ZIPREL)/$(APPNAME).zip; \
	fi

	@echo "  >> creating destination directory $(ZIPREL)"	
	@if [ ! -d $(ZIPREL) ]; \
	then \
		mkdir -p $(ZIPREL); \
	fi

	@echo "  >> setting directory permissions for $(ZIPREL)"
	@if [ ! -w $(ZIPREL) ]; \
	then \
		chmod 755 $(ZIPREL); \
	fi

# zip .png files without compression
# do not zip up Makefiles, or any files ending with '~'
	@echo "  >> creating application zip $(ZIPREL)/$(APPNAME).zip"	
	@if [ -d $(SOURCEREL)/$(APPNAME) ]; \
	then \
		(zip -0 -r "$(ZIPREL)/$(APPNAME).zip" . -i \*.png $(ZIP_EXCLUDE)); \
		(zip -9 -r "$(ZIPREL)/$(APPNAME).zip" . -x \*~ -x \*.png -x Makefile $(ZIP_EXCLUDE)); \
	else \
		echo "Source for $(APPNAME) not found at $(SOURCEREL)/$(APPNAME)"; \
	fi

	@echo "*** developer zip $(APPTITLE) $(FULLVERSION) complete ***"

install: $(APPNAME)
	@echo "Installing $(APPTITLE) to host $(ROKU_DEV_TARGET)"
	@$(CURL) -s -S -F "mysubmit=Install" -F "archive=@$(ZIPREL)/$(APPNAME).zip" -F "passwd=" http://$(ROKU_DEV_TARGET)/plugin_install | grep "<font color" | sed "s/<font color=\"red\">//"
	@echo "*** install $(APPTITLE) $(FULLVERSION) complete ***"

pkg: ROKU_PKG_PASSWORD ?= "$(shell read -p "Roku packaging password: " REPLY; echo $$REPLY)"
pkg: install
	@echo "*** Creating Package ***"

	@echo "  >> creating destination directory $(PKGREL)"	
	@if [ ! -d $(PKGREL) ]; \
	then \
		mkdir -p $(PKGREL); \
	fi

	@echo "  >> setting directory permissions for $(PKGREL)"
	@if [ ! -w $(PKGREL) ]; \
	then \
		chmod 755 $(PKGREL); \
	fi

	@echo "Packaging  $(APPNAME) on host $(ROKU_DEV_TARGET)"
	$(CURL) -s -S -Fmysubmit=Package -Fapp_name=$(APPNAME)/$(VERSION) -Fpasswd=$(ROKU_PKG_PASSWORD) -Fpkg_time=`date +%s` "http://$(ROKU_DEV_TARGET)/plugin_package" | grep 'pkgs' | sed 's/.*href=\"\([^\"]*\)\".*/\1/' | sed 's#pkgs//##' | xargs -I{} http -v --auth-type digest --auth $(ROKU_DEV_USERNAME):$(ROKU_DEV_PASSWORD) -o $(PKGREL)/$(APPTITLE)_{} -d http://$(ROKU_DEV_TARGET)/pkgs/{}

	@echo "*** Package  $(APPTITLE) $(FULLVERSION) complete ***"

remove:
	@echo "Removing $(APPNAME) from host $(ROKU_DEV_TARGET)"
	@$(CURL) -s -S -F "mysubmit=Delete" -F "archive=" -F "passwd=" http://$(ROKU_DEV_TARGET)/plugin_install | grep "<font color" | sed "s/<font color=\"red\">//"

upload: ROKU_PORTAL_USERNAME ?= "$(shell read -p "Roku email: " REPLY; echo $$REPLY)"
upload: ROKU_PORTAL_PASSWORD ?= "$(shell read -p "Roku password: " REPLY; echo $$REPLY)"
upload: ROKU_PKG_VERSION ?= 1.1
upload: ROKU_PKG_FIRMWARE ?= 50101050
upload: SESSIONID ?= $(shell date +%s)
upload: ROKU_OUTPUT ?= /tmp/roku_output.html
upload: HTTP := http -p hb -o $(ROKU_OUTPUT) --session $(SESSIONID)
upload: pkg
	@if [ -z $(APPID) ]; \
	then \
		echo "APPID must be set, try making a target that sets it"; \
		exit 1; \
	fi

	@echo "*** Uploading Package for $(APPTITLE) $(FULLVERSION) ($(APPID)) ***"

# Step 1: Load the signin page in a new httpie session to get
# whatever cookies and session info we need.
	@echo "Loading signin page to establish cookies and session"
	@$(HTTP) https://my.roku.com/signin
	@head -1 $(ROKU_OUTPUT) | grep '200 OK' || exit 2

# Step 2: Sign in using our portal credentials.
	@echo "Authenticating to owner.roku.com"
	@$(HTTP) -f POST https://owner.roku.com/Login api==json r==`date +%s`000 Origin:https://owner.roku.com email="$(ROKU_PORTAL_USERNAME)" password="$(ROKU_PORTAL_PASSWORD)" remember="false"
	@head -1 $(ROKU_OUTPUT) | grep '200 OK' || exit 3

# Step 3: Navigate to our package page
	@echo "Navigating to package page for $(APPTITLE) ($(APPID))"
	$(HTTP) https://owner.roku.com/Developer/Apps/Packages/$(APPID)
	@head -1 $(ROKU_OUTPUT) | grep '200 OK' || exit 4

# Step 4: Upload our package
	$(eval PKGFILE := $(shell ls -t $(PKGREL)/$(APPTITLE)_* | head -1))
	@echo "Uploading package at $(PKGFILE)..."
	$(HTTP) -f POST https://owner.roku.com/Developer/Apps/SavePackage/$(APPID) Origin:https://owner.roku.com AppUpload@$(PKGFILE) Unpublished.Version=$(ROKU_PKG_VERSION) Unpublished.MinFirmwareRevision=$(ROKU_PKG_FIRMWARE) __RequestVerificationToken="`sed -n -e 's/^.*RequestVerificationToken.*value="\([^"]*\)".*$$/\1/p' $(ROKU_OUTPUT)`"
	@head -1 $(ROKU_OUTPUT) | grep '200 OK' || exit 5

# Step 5: Figure out the code for the new package
	@echo "Navigating back to package page for $(APPTITLE) ($(APPID))"
	$(HTTP) https://owner.roku.com/Developer/Apps/Packages/$(APPID)
	@head -1 $(ROKU_OUTPUT) | grep '200 OK' || exit 6
	@curl -X POST --data-urlencode "payload={\"attachments\": [{\"fallback\": \"A package has been uploaded to the $(APPTITLE) channel\", \"color\": \"good\", \"pretext\": \"A new package has been uploaded to the Roku store\", \"fields\": [{\"title\": \"Channel\", \"value\": \"$(APPTITLE) v$(FULLVERSION)\", \"short\": true}, {\"title\": \"Link\", \"value\": \"<`sed -n -e 's#^.*href="\(/add/\(.*\)\)".*$$#https://owner.roku.com\1\|\2#p' $(ROKU_OUTPUT) | head -1`>\", \"short\": true}]}]}" https://hooks.slack.com/services/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
	@echo "Uploaded package is available at:"
	@sed -n -e 's/^.*href="\(\/add\/.*\)".*$$/https:\/\/owner.roku.com\1/p' $(ROKU_OUTPUT) | head -1

publish: ROKU_PORTAL_USERNAME ?= "$(shell read -p "Roku email: " REPLY; echo $$REPLY)"
publish: ROKU_PORTAL_PASSWORD ?= "$(shell read -p "Roku password: " REPLY; echo $$REPLY)"
publish: SESSIONID ?= $(shell date +%s)
publish: ROKU_OUTPUT ?= /tmp/roku_output.html
publish: HTTP := http -p hb -o $(ROKU_OUTPUT) --session $(SESSIONID)
publish:
	@if [ -z $(APPID) ]; \
	then \
		echo "APPID must be set, try making a target that sets it"; \
		exit 1; \
	fi

	@echo "*** Publishing Package for $(APPTITLE) $(FULLVERSION) ($(APPID)) ***"

# Step 1: Load the signin page in a new httpie session to get
# whatever cookies and session info we need.
	@echo "Loading signin page to establish cookies and session"
	@$(HTTP) https://my.roku.com/signin
	@head -1 $(ROKU_OUTPUT) | grep '200 OK' || exit 2

# Step 2: Sign in using our portal credentials.
	@echo "Authenticating to owner.roku.com"
	@$(HTTP) -f POST https://owner.roku.com/Login api==json r==`date +%s`000 Origin:https://owner.roku.com email="$(ROKU_PORTAL_USERNAME)" password="$(ROKU_PORTAL_PASSWORD)" remember="false"
	@head -1 $(ROKU_OUTPUT) | grep '200 OK' || exit 3

# Step 3: Navigate to our package page
	@echo "Navigating to package page for $(APPTITLE) ($(APPID))"
	$(HTTP) https://owner.roku.com/Developer/Apps/Packages/$(APPID)
	@head -1 $(ROKU_OUTPUT) | grep '200 OK' || exit 4

# Step 4: Publish our package
	@echo "Publishing package..."
	$(HTTP) https://owner.roku.com/Developer/Apps/Publish/$(APPID) Origin:https://owner.roku.com
	@head -1 $(ROKU_OUTPUT) | grep '302 Found' || exit 5
	@grep 'Location: /Developer/Apps/Packages/$(APPID)' $(ROKU_OUTPUT) || exit 6

	@curl -X POST --data-urlencode "payload={\"attachments\": [{\"fallback\": \"A package has been published to the $(APPTITLE) channel\", \"color\": \"good\", \"pretext\": \"A new package has been published in the Roku store\", \"fields\": [{\"title\": \"Channel\", \"value\": \"$(APPTITLE) $(FULLVERSION)\", \"short\": true}]}]}" https://hooks.slack.com/services/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

	@echo "*** Published Package! $(APPTITLE) $(FULLVERSION) ($(APPID)) ***"
