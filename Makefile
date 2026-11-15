SHELL := /bin/bash
VERSION := 1.0
ARCH := amd64
IMAGE := foxoos-$(VERSION)-$(ARCH)
LB_ISO := foxoos-$(VERSION)-$(ARCH).hybrid.iso
ISO := $(CURDIR)/$(IMAGE).iso

.PHONY: all build reconfigure clean distclean test sha256 manifest help

all: build

build:
	lb build
	@test -f "$(LB_ISO)" || { echo "ERROR: $(LB_ISO) not found"; exit 1; }
	@cp -f "$(LB_ISO)" "$(ISO)"
	@sha256sum "$(ISO)" | tee "$(ISO).sha256"
	@test -f "$(IMAGE).packages" || { echo "WARNING: $(IMAGE).packages not found"; exit 1; }
	@echo "package manifest: $(IMAGE).packages"

reconfigure:
	lb clean --all
	rm -rf config/binary config/bootstrap config/chroot config/common config/source .build
	./auto/config

clean:
	lb clean

distclean:
	lb clean --all
	rm -rf binary chroot cache .build config/binary config/bootstrap config/chroot config/common config/source
	rm -f *.iso *.iso.sha256 *.packages
	rm -f $(IMAGE).iso $(IMAGE).iso.sha256 $(IMAGE).packages

test:
	./scripts/test-qemu.sh "$(ISO)"

sha256:
	@test -f "$(ISO)" || { echo "ERROR: $(ISO) not found; run make build"; exit 1; }
	@sha256sum "$(ISO)"

manifest:
	@test -f binary/live/filesystem.packages || { echo "ERROR: no manifest; run make build"; exit 1; }
	@grep -E '^(ii|hi)  (systemd|systemd-sysv|systemd-timesyncd|libnss-systemd|libpam-systemd|sysvinit-core|openrc|live-config|live-boot|network-manager|dbus|udev|systemd-standalone)' binary/live/filesystem.packages || true

help:
	@echo "make build        zbuduj ISO (live-build)"
	@echo "make reconfigure  wygeneruj config od nowa (po zmianie auto/config)"
	@echo "make test         boot test ISO w QEMU (wymaga qemu-system-x86 + expect)"
	@echo "make manifest     pokaz wazne pakiety z manifestu"
	@echo "make sha256       pokaz SHA-256 gotowego ISO"
	@echo "make distclean    usun artefakty budowania"
