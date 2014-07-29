#! /usr/bin/make

# It is not safe to build multiple targets at one time with this
# makefile.  Please build each target independently, in a separate
# make process.  Concurrently building multiple targets in separate
# processes is safe.

# one of: amd64 armel armhf i386
ARCHITECTURE = armel
# one of: beaglebone dreamplug raspberry(pi) virtualbox
MACHINE = dreamplug
# one of: card hdd usb
DESTINATION = card
# one of: debian's distributions
SUITE = sid
# one of: true or false
SOURCE = false
# user's ID
OWNER = 1000

# don't change these lines.  just don't.
BUILD = $(MACHINE)-$(ARCHITECTURE)-$(DESTINATION)
TODAY = $(shell date +%Y-%m-%d)
SHORTNAME = freedombox-unstable_$(TODAY)_$(BUILD)
FULLNAME = build/$(SHORTNAME)
WEEKLY_DIR = torrent/freedombox-unstable_$(TODAY)
IMAGE = $(FULLNAME).img
ARCHIVE_FILE = $(IMAGE)
ARCHIVE = $(FULLNAME).tar.bz2
TAR = tar --checkpoint=1000 --checkpoint-action=dot -cjvf
MAKE_IMAGE = ARCHITECTURE=$(ARCHITECTURE) DESTINATION=$(DESTINATION) \
    MACHINE=$(MACHINE) SOURCE=$(SOURCE) SUITE=$(SUITE) OWNER=$(OWNER) \
    bin/mk_freedombox_image $(FULLNAME)
SIGN = -gpg --output $(SIGNATURE) --detach-sig $(ARCHIVE)
SIGNATURE = $(ARCHIVE).sig
POST_BUILD = ""

beaglebone dreamplug guruplug rasbperry virtualbox: simple-image
simple-image: prep
	$(MAKE_IMAGE)
	$(POST_BUILD)
	$(TAR) $(ARCHIVE) $(ARCHIVE_FILE)
	@echo ""
	$(SIGN)
	@echo "Build complete."

virtualbox-register: virtualbox
# register a virtualbox vm: http://www.virtualbox.org/manual/ch07.html
	-vboxmanage unregistervm $(SHORTNAME)
	-vboxmanage createvm --name $(SHORTNAME) --ostype Debian \
	    --register
	vboxmanage modifyvm $(SHORTNAME) --memory 256 --acpi on \
	    --nic1 bridged --vrde on --vrdeport 3389 \
	    --vrdeauthtype external
	vboxmanage storagectl $(SHORTNAME) --name "IDE Controller" \
	     --add ide --controller PIIX4
	vboxmanage storageattach $(SHORTNAME) --storagectl \
	    "IDE Controller" --port 0 --device 0 --type hdd --medium \
	    $(FULLNAME).vdi
	vboxmanage snapshot $(SHORTNAME) take "0: Built"
# end virtualbox section.

prep: Makefile
	mkdir -p build
ifeq ("dreamplug", $(MAKECMDGOALS))
	$(eval ARCHITECTURE = armel)
	$(eval MACHINE = dreamplug)
	$(eval DESTINATION = card)
else ifeq ("guruplug", $(MAKECMDGOALS))
	$(eval ARCHITECTURE = armel)
	$(eval MACHINE = dreamplug)
	$(eval DESTINATION = usb)
else ifeq ("raspberry", $(MAKECMDGOALS))
	$(eval ARCHITECTURE = armel)
	$(eval MACHINE = raspberry)
	$(eval DESTINATION = card)
else ifeq ("beaglebone", $(MAKECMDGOALS))
	$(eval ARCHITECTURE = armhf)
	$(eval MACHINE = beaglebone)
	$(eval DESTINATION = card)
# vbox images can have multiple targets, match on any of them.
else ifneq ($(findstring virtualbox, $(MAKECMDGOALS)), "")
	$(eval ARCHITECTURE = i386)
	$(eval MACHINE = virtualbox)
	$(eval DESTINATION = hdd)
	$(eval POST_BUILD = vboxmanage convertdd $(FULLNAME).img $(FULLNAME).vdi)
	$(eval ARCHIVE_FILE = $(FULLNAME).vdi)
endif

clean:
	-rm -f $(IMAGE) $(ARCHIVE)

distclean: clean
	sudo rm -rf build
