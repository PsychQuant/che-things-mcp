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

# Step 1: Build for both architectures
echo "[1/4] Building for Apple Silicon (arm64)..."
cd "$PROJECT_DIR"
swift build -c release --arch arm64

echo "[2/4] Building for Intel (x86_64)..."
swift build -c release --arch x86_64

# Step 2: Create Universal Binary
echo "[3/4] Creating Universal Binary..."
mkdir -p "$SERVER_DIR"

ARM64_BINARY="$PROJECT_DIR/.build/arm64-apple-macosx/release/CheThingsMCP"
X64_BINARY="$PROJECT_DIR/.build/x86_64-apple-macosx/release/CheThingsMCP"
UNIVERSAL_BINARY="$SERVER_DIR/CheThingsMCP"

if [[ -f "$ARM64_BINARY" && -f "$X64_BINARY" ]]; then
    # Remove first: writing over a binary that a running process holds open leaves a stale
    # code-signature cache per inode, and the kernel then kills the new binary on exec.
    rm -f "$UNIVERSAL_BINARY"
    lipo -create "$ARM64_BINARY" "$X64_BINARY" -output "$UNIVERSAL_BINARY"
    chmod +x "$UNIVERSAL_BINARY"
    echo "Created Universal Binary: $UNIVERSAL_BINARY"
else
    echo "Error: Could not find architecture-specific binaries"
    echo "  ARM64: $ARM64_BINARY (exists: $(test -f "$ARM64_BINARY" && echo yes || echo no))"
    echo "  X64: $X64_BINARY (exists: $(test -f "$X64_BINARY" && echo yes || echo no))"
    exit 1
fi

# Step 3.5: Sign + notarize for distribution.
# Required for releases: on macOS 26 an ad-hoc signed binary cannot create a TCC
# (Automation / Apple Events) grant; Developer ID signing + Hardened Runtime +
# notarization is the path that lets end users get the permission dialog.
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
elif ! security find-identity -p codesigning -v 2>/dev/null | grep -qF "$DEVELOPER_ID"; then
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
    mcpb pack
    echo ""
    echo "=== Build Complete ==="
    echo "MCPB package: $MCPB_DIR/che-things-mcp.mcpb"
else
    echo "=== Build Complete (Manual Pack Required) ==="
    echo "mcpb CLI not found. To pack the bundle:"
    echo "  1. Install: npm install -g @anthropic-ai/mcpb"
    echo "  2. Run: cd mcpb && mcpb pack"
fi

echo ""
echo "Contents of mcpb/:"
ls -la "$MCPB_DIR"
