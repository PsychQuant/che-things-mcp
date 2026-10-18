#!/bin/bash
# Build script for che-things-mcp MCPB package
# Creates a Universal Binary and packages it for Claude Desktop

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MCPB_DIR="$PROJECT_DIR/mcpb"
SERVER_DIR="$MCPB_DIR/server"

echo "=== che-things-mcp MCPB Build Script ==="
echo "Project directory: $PROJECT_DIR"
echo ""

# Step 1: Build a universal binary (arm64 + x86_64) in ONE invocation.
# Why not one build per architecture: with the swiftbuild build system (the default since
# Swift 6.4) every --arch value writes into the same directory, so a second build overwrites
# the first, and the old per-architecture directories (.build/<arch>-apple-macosx/release)
# only hold leftovers from earlier toolchains. Shipping one of those leftovers would put old
# code under a new version number, so the product is located with --show-bin-path instead.
echo "[1/4] Building universal binary (arm64 + x86_64)..."
cd "$PROJECT_DIR"
swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path | tail -1)"
BUILT_BINARY="$BIN_DIR/CheThingsMCP"

# Step 2: Check the product is what we think it is, BEFORE it is copied, signed or notarized.
echo "[2/4] Verifying the built binary..."
if [[ ! -f "$BUILT_BINARY" ]]; then
    echo "Error: built binary not found at $BUILT_BINARY"
    exit 1
fi
EXPECTED_VERSION="$(sed -n 's/.*static let current = "\([^"]*\)".*/\1/p' "$PROJECT_DIR/Sources/CheThingsMCPCore/Version.swift" | head -1)"
if [[ -z "$EXPECTED_VERSION" ]]; then
    echo "Error: could not read AppVersion.current from Version.swift"
    exit 1
fi
ARCHS="$(lipo -archs "$BUILT_BINARY")"
for arch in arm64 x86_64; do
    if [[ " $ARCHS " != *" $arch "* ]]; then
        echo "Error: $BUILT_BINARY has no $arch slice (found: $ARCHS)"
        exit 1
    fi
done
CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/che-things-mcp-build.XXXXXXXX")"
trap 'rm -rf "$CHECK_DIR"' EXIT
for arch in arm64 x86_64; do
    SLICE="$CHECK_DIR/slice-$arch"
    lipo -thin "$arch" "$BUILT_BINARY" -output "$SLICE"
    # (a) the version literal from Version.swift is in the slice, (b) the newest CLI code is in
    # it, (c) the Info.plist is embedded. A stale binary fails at least one of these.
    if ! strings -a "$SLICE" | grep -qx -- "$EXPECTED_VERSION"; then
        echo "Error: the $arch slice does not contain version $EXPECTED_VERSION; this is an old build"
        exit 1
    fi
    if ! strings -a "$SLICE" | grep -q -- "--print-tcc-path"; then
        echo "Error: the $arch slice lacks the --print-tcc-path code; this is an old build"
        exit 1
    fi
    if ! otool -s __TEXT __info_plist "$SLICE" | grep -q "Contents of"; then
        echo "Error: the $arch slice has no embedded Info.plist"
        exit 1
    fi
    echo "  ✓ $arch: version $EXPECTED_VERSION, --print-tcc-path, embedded Info.plist"
done

# Step 3: Put the verified product into mcpb/server.
echo "[3/4] Creating Universal Binary..."
mkdir -p "$SERVER_DIR"
UNIVERSAL_BINARY="$SERVER_DIR/CheThingsMCP"
# Remove first: writing over a binary that a running process holds open leaves a stale
# code-signature cache per inode, and the kernel then kills the new binary on exec.
rm -f "$UNIVERSAL_BINARY"
cp "$BUILT_BINARY" "$UNIVERSAL_BINARY"
chmod +x "$UNIVERSAL_BINARY"
echo "Created Universal Binary: $UNIVERSAL_BINARY"

# Step 3.5: Sign + notarize for distribution.
# Required for releases. On macOS 26 ad-hoc signed binaries were reported (che-ical-mcp
# issues 44 and 154) to be unable to create TCC grants for Calendar / Reminders; for
# Automation / Apple Events, which this project uses, that is inferred and not yet observed.
# Developer ID signing + Hardened Runtime + notarization is the distribution path either way.
#
# Behavior:
#   SKIP_CODESIGN=1 (or "true") -> skip unconditionally (local iteration override)
#   REQUIRE_CODESIGN=1 -> fail-fast if signing prerequisites are missing
#     (used by `make release-signed`: the canonical release path must not
#      silently produce an unsigned artifact)
#   No DEVELOPER_ID env or no cert in keychain -> auto-skip with a warning
#     (fork-friendly default for direct script invocation)
#   Otherwise -> run sign-and-notarize.sh
echo ""
SHOULD_SIGN=true
SKIP_REASON=""
if [[ "${SKIP_CODESIGN:-}" == "1" || "${SKIP_CODESIGN:-}" == "true" ]]; then
    SHOULD_SIGN=false
    SKIP_REASON="SKIP_CODESIGN=$SKIP_CODESIGN"
elif [[ -z "${DEVELOPER_ID:-}" ]]; then
    SHOULD_SIGN=false
    SKIP_REASON="DEVELOPER_ID env not set"
elif ! security find-identity -p codesigning -v 2>/dev/null | grep -qiF -- "$DEVELOPER_ID"; then
    SHOULD_SIGN=false
    SKIP_REASON="codesigning identity '$DEVELOPER_ID' not in keychain"
fi

if [[ "$SHOULD_SIGN" == "false" ]]; then
    if [[ "${REQUIRE_CODESIGN:-}" == "1" || "${REQUIRE_CODESIGN:-}" == "true" ]]; then
        # Canonical release path: refuse to produce an unsigned artifact silently
        echo "[3.5/4] ✗ Refusing to skip signing: REQUIRE_CODESIGN=$REQUIRE_CODESIGN" >&2
        echo "        Reason: $SKIP_REASON" >&2
        echo "        Fix: set DEVELOPER_ID + NOTARY_PROFILE, install a Developer ID Application" >&2
        echo "             cert, and make sure it is in your login keychain." >&2
        echo "        See README 'Signing & Notarization' for one-time setup." >&2
        exit 1
    fi
    # Fork-friendly auto-skip: warn and continue with an unsigned binary
    echo "[3.5/4] Skipping codesign + notarize."
    echo "  Reason: $SKIP_REASON"
    echo "  ⚠ The resulting binary is ad-hoc signed; suitable for local dev only."
    echo "  ⚠ For a release-quality artifact on macOS 26: set DEVELOPER_ID + NOTARY_PROFILE,"
    echo "    install a Developer ID Application cert, then run \`make release-signed\`."
else
    echo "[3.5/4] Signing + notarizing for distribution..."
    "$SCRIPT_DIR/sign-and-notarize.sh" "$UNIVERSAL_BINARY"
fi

# Verify Universal Binary
echo ""
echo "Binary info:"
file "$UNIVERSAL_BINARY"
echo ""
echo "Architectures:"
lipo -info "$UNIVERSAL_BINARY"

# Step 3: Check for required files
echo ""
echo "[4/4] Checking MCPB package contents..."

REQUIRED_FILES=(
    "$MCPB_DIR/manifest.json"
    "$MCPB_DIR/PRIVACY.md"
    "$SERVER_DIR/CheThingsMCP"
)

MISSING=0
for f in "${REQUIRED_FILES[@]}"; do
    if [[ -f "$f" ]]; then
        echo "  ✓ $(basename "$f")"
    else
        echo "  ✗ $(basename "$f") - MISSING"
        MISSING=1
    fi
done

# Check for icon (optional but recommended)
if [[ -f "$MCPB_DIR/icon.png" ]]; then
    echo "  ✓ icon.png"
else
    echo "  ⚠ icon.png - MISSING (optional but recommended for submission)"
fi

if [[ $MISSING -eq 1 ]]; then
    echo ""
    echo "Error: Missing required files. Please create them before packaging."
    exit 1
fi

# Step 4: Pack MCPB (if mcpb CLI is available)
echo ""
if command -v mcpb &> /dev/null; then
    echo "Packing MCPB bundle..."
    cd "$MCPB_DIR"
    # Name the output explicitly: without it `mcpb pack` names the file after the folder
    # (mcpb/mcpb.mcpb, which .gitignore hides), and the file this script reports and the
    # repository tracks (che-things-mcp.mcpb) would stay at whatever an earlier run left.
    MCPB_OUTPUT="$MCPB_DIR/che-things-mcp.mcpb"
    rm -f "$MCPB_OUTPUT" "$MCPB_DIR/mcpb.mcpb"
    mcpb pack . "$MCPB_OUTPUT"
    if [[ ! -s "$MCPB_OUTPUT" ]]; then
        echo "Error: mcpb pack did not produce $MCPB_OUTPUT"
        exit 1
    fi
    # The bundle must carry the binary that was just verified (and, on a release, signed).
    if ! unzip -p "$MCPB_OUTPUT" server/CheThingsMCP | cmp -s - "$UNIVERSAL_BINARY"; then
        echo "Error: server/CheThingsMCP inside $MCPB_OUTPUT differs from $UNIVERSAL_BINARY"
        exit 1
    fi
    echo ""
    echo "=== Build Complete ==="
    echo "MCPB package: $MCPB_OUTPUT"
else
    echo "=== Build Complete (Manual Pack Required) ==="
    echo "mcpb CLI not found. To pack the bundle:"
    echo "  1. Install: npm install -g @anthropic-ai/mcpb"
    echo "  2. Run: cd mcpb && mcpb pack"
fi

echo ""
echo "Contents of mcpb/:"
ls -la "$MCPB_DIR"
