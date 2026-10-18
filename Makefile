BINARY_NAME = CheThingsMCP
# ?= so that `ENTITLEMENTS=/abs/path make release-signed` (an environment variable) is honored;
# with a plain `=` the assignment here would silently override it.
ENTITLEMENTS ?= Sources/CheThingsMCP/Entitlements.plist

.PHONY: build release test clean install install-signed verify-developer-id verify-release-env release-signed

build:
	swift build

release:
	swift build -c release

test:
	swift test

clean:
	swift package clean

# Local dev install, ad-hoc signed. DEV ONLY: on macOS 26 ad-hoc signed binaries were reported
# (che-ical-mcp issues 44 and 154) to be unable to create TCC grants for Calendar / Reminders;
# for Automation, which this project uses, that is inferred and not yet observed here. Use
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

# Distribution release: runs the tests, builds the universal binary, checks it is the current
# code, signs it with Developer ID, checks the signed binary's entitlements, notarizes via
# notarytool, and packages the .mcpb. The tests run first because nothing else in this chain
# does: they read the plist files and the version fields that the signing step then uses.
# REQUIRE_CODESIGN=1 makes signing mandatory: a missing DEVELOPER_ID, certificate or
# notarytool profile fails fast instead of silently producing an unsigned artifact.
# Pass ENTITLEMENTS as an absolute path only if you override the default.
# Checked before the tests so that a missing variable fails in a second, not after the tests.
verify-release-env:
	@: $${DEVELOPER_ID:?DEVELOPER_ID not set. See README 'Signing & Notarization' for setup.}
	@: $${NOTARY_PROFILE:?NOTARY_PROFILE not set. See README 'Signing & Notarization' for setup.}

release-signed: verify-release-env test
	@echo "NOTE: the permission flow of the resulting binary must still be verified by hand"
	@echo "  before tagging: install it and run \`CheThingsMCP --setup\`."
	@echo ""
	REQUIRE_CODESIGN=1 ./scripts/build-mcpb.sh
