BINARY_NAME = CheThingsMCP
ENTITLEMENTS = Sources/CheThingsMCP/Entitlements.plist

.PHONY: build release test clean install install-signed verify-developer-id release-signed

build:
	swift build

release:
	swift build -c release

test:
	swift test

clean:
	swift package clean

# Local dev install, ad-hoc signed. DEV ONLY: on macOS 26 an ad-hoc signed binary cannot
# create the TCC (Automation) grant, so the permission dialog may never appear. Use
# `make install-signed` to test the permission flow on your own machine.
# `rm -f` first: copying over a binary that a running process holds open leaves a stale
# code-signature cache per inode and the kernel kills the new binary on exec.
install: release
	rm -f ~/bin/$(BINARY_NAME)
	cp .build/release/$(BINARY_NAME) ~/bin/$(BINARY_NAME)
	chmod +x ~/bin/$(BINARY_NAME)
	codesign --force --sign - ~/bin/$(BINARY_NAME)
	@echo "Installed: ~/bin/$(BINARY_NAME) (ad-hoc signed, dev only)"

# Dev install with a Developer ID signature and the entitlements, WITHOUT notarization.
# Slower than `make install`, but it is what you need to test the macOS 26 permission
# flow on your own machine, and it skips the notarytool wait (1-15 minutes) that
# `make release-signed` adds. NOT for distribution: notarization is required there.
# Needs DEVELOPER_ID only; NOTARY_PROFILE is unused here.
verify-developer-id:
	@: $${DEVELOPER_ID:?DEVELOPER_ID not set. See README 'Signing & Notarization'. NOTARY_PROFILE is not needed for install-signed.}

install-signed: verify-developer-id release
	rm -f ~/bin/$(BINARY_NAME)
	cp .build/release/$(BINARY_NAME) ~/bin/$(BINARY_NAME)
	chmod +x ~/bin/$(BINARY_NAME)
	codesign --force \
	         --sign "$$DEVELOPER_ID" \
	         --options runtime \
	         --entitlements $(ENTITLEMENTS) \
	         ~/bin/$(BINARY_NAME)
	@echo "Installed: ~/bin/$(BINARY_NAME) (Developer ID signed, NOT notarized, dev only)"

# Distribution release: builds the universal binary, signs it with Developer ID, checks the
# signed binary's entitlements, notarizes via notarytool, and packages the .mcpb.
# REQUIRE_CODESIGN=1 makes signing mandatory: a missing DEVELOPER_ID, certificate or
# notarytool profile fails fast instead of silently producing an unsigned artifact.
# Pass ENTITLEMENTS as an absolute path only if you override the default.
release-signed:
	@echo "NOTE: macOS 26 TCC behavior of the resulting binary must still be verified by hand"
	@echo "  before tagging: install it and run \`CheThingsMCP --setup\`."
	@echo ""
	@: $${DEVELOPER_ID:?DEVELOPER_ID not set. See README 'Signing & Notarization' for setup.}
	@: $${NOTARY_PROFILE:?NOTARY_PROFILE not set. See README 'Signing & Notarization' for setup.}
	REQUIRE_CODESIGN=1 ./scripts/build-mcpb.sh
