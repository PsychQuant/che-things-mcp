#!/bin/bash
# Sign and notarize the CheThingsMCP universal binary for outside-App-Store distribution.
#
# Why Developer ID + Hardened Runtime + notarization: on macOS 26 ad-hoc signed
# binaries were reported (che-ical-mcp issues 44 and 154) to be unable to create
# TCC grants for Calendar / Reminders. For Automation (Apple Events), which this
# project uses, that is inferred from Apple's documentation and not yet observed.
#
# Stapling is NOT performed: stapler staple does not support raw Mach-O
# binaries (only .app/.pkg/.dmg). A file that carries a quarantine attribute
# (for example one downloaded in a browser) is checked online by Gatekeeper at
# first launch; a binary fetched with curl does not carry that attribute.
#
# Usage:
#   scripts/sign-and-notarize.sh <path/to/binary>
#
# Required env vars (no defaults — fork-friendly, no maintainer PII in error messages):
#   DEVELOPER_ID    — codesigning identity, e.g. "Developer ID Application: Your Name (TEAMID)"
#   NOTARY_PROFILE  — notarytool keychain profile name (set up via: xcrun notarytool store-credentials <name> ...)
#
# Optional env var:
#   ENTITLEMENTS    — entitlements .plist path (default: "Sources/CheThingsMCP/Entitlements.plist")

set -euo pipefail

BINARY="${1:?Usage: $0 <path/to/binary>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENTITLEMENTS="${ENTITLEMENTS:-$PROJECT_DIR/Sources/CheThingsMCP/Entitlements.plist}"

# Pre-flight: required env vars
if [[ -z "${DEVELOPER_ID:-}" ]]; then
    echo "Error: DEVELOPER_ID is not set." >&2
    echo "       Export your Developer ID Application identity:" >&2
    echo "       export DEVELOPER_ID='Developer ID Application: Your Name (TEAMID)'" >&2
    echo "       Find available identities: security find-identity -p codesigning -v" >&2
    exit 1
fi

if [[ -z "${NOTARY_PROFILE:-}" ]]; then
    echo "Error: NOTARY_PROFILE is not set." >&2
    echo "       Export your notarytool keychain profile name:" >&2
    echo "       export NOTARY_PROFILE='your-profile-name'" >&2
    echo "       Set up profile (one-time): xcrun notarytool store-credentials <name> --apple-id <id> --team-id <team-id>" >&2
    echo "       (notarytool will prompt for app-specific password — do NOT pass it on the command line)" >&2
    exit 1
fi

if [[ ! -f "$BINARY" ]]; then
    echo "Error: binary not found at $BINARY" >&2
    exit 1
fi

if [[ ! -f "$ENTITLEMENTS" ]]; then
    echo "Error: entitlements file not found at $ENTITLEMENTS" >&2
    exit 1
fi

# Pre-flight: verify cert exists in keychain (avoids cryptic codesign error mid-flow)
# Capture first: with pipefail, `security ... | grep -q` can fail with SIGPIPE when grep
# exits early, which would look like a missing certificate. -i because a SHA-1 may be lower case.
IDENTITIES="$(security find-identity -p codesigning -v 2>/dev/null || true)"
if ! grep -qiF -- "$DEVELOPER_ID" <<< "$IDENTITIES"; then
    echo "Error: codesigning identity not found in keychain: $DEVELOPER_ID" >&2
    echo "       Available identities:" >&2
    security find-identity -p codesigning -v 2>&1 | grep -E '"[^"]*"' | sed 's/^/         /' >&2
    exit 1
fi

# Pre-flight: verify notarytool keychain profile exists (avoids submit-then-fail)
if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "Error: notarytool keychain profile '$NOTARY_PROFILE' not configured." >&2
    echo "       Set up with: xcrun notarytool store-credentials $NOTARY_PROFILE \\" >&2
    echo "                      --apple-id <your-apple-id> --team-id <your-team-id>" >&2
    exit 1
fi

# One private work directory for every temp file, removed on any exit (including
# SIGINT/SIGTERM/error). BSD `mktemp -t name-XXXXXXXX` keeps the literal X's and
# appends a random suffix, so appending ".zip" to it would leak an empty file per run.
WORKDIR="$(mktemp -d "${TMPDIR:-/tmp}/sign-and-notarize.XXXXXXXX")"
trap 'rm -rf "$WORKDIR"' EXIT INT TERM

echo "=== sign-and-notarize: $BINARY ==="
echo "  Identity:      $DEVELOPER_ID"
echo "  Profile:       $NOTARY_PROFILE"
echo "  Entitlements:  $ENTITLEMENTS"
echo ""

# Step 1: codesign with hardened runtime
echo "[1/4] Signing with Developer ID + hardened runtime..."
codesign --force \
    --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "$DEVELOPER_ID" \
    "$BINARY"

# Step 2: verify signature locally
# Note: this is a gating verify (codesign --verify exit code is checked); the |head -5
# is for output trimming only. Under set -o pipefail, if codesign verify fails it will
# write to stderr and exit non-zero, propagating up because head reads <= 5 lines and
# closes its stdin → codesign gets SIGPIPE → pipeline exit non-zero → set -e aborts.
echo ""
echo "[2/4] Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$BINARY" 2>&1 | head -5

# Step 2.5: entitlements gate. The SIGNED binary must carry the Apple Events
# entitlement as boolean true. Under the Hardened Runtime, Apple documents this
# entitlement as what lets an app prompt for permission to send Apple events;
# without it macOS may show no dialog at all (observed for Calendar in
# che-ical-mcp issue 154; for Apple Events it is inferred, not yet observed).
# This guards the signed artifact itself: a wrong ENTITLEMENTS path would pass
# the source-level PlistAndHelpTests yet still ship a broken binary. It runs
# before notarization so a miss fails in seconds, not after a 1-15 minute wait.
echo ""
echo "[2.5/4] Verifying the Apple Events entitlement on the signed binary..."
ENT_PLIST="$WORKDIR/entitlements.plist"
if ! codesign -d --entitlements "$ENT_PLIST" --xml "$BINARY"; then
    echo "Error: could not read entitlements from signed binary ('$BINARY')." >&2
    echo "       codesign -d --entitlements failed (see codesign output above)." >&2
    rm -f "$ENT_PLIST"
    exit 1
fi
# A binary with no entitlements at all makes codesign write no file; say so plainly
# instead of letting PlistBuddy print "File Doesn't Exist, Will Create" as the value.
if [ ! -s "$ENT_PLIST" ]; then
    echo "Error: the signed binary carries NO entitlements (need com.apple.security.automation.apple-events = true)." >&2
    echo "       Check that ENTITLEMENTS ('$ENTITLEMENTS') exists and that codesign received" >&2
    echo "       --entitlements; a binary signed without it (for example ad-hoc) has none." >&2
    rm -f "$ENT_PLIST"
    exit 1
fi
# Parse as a plist (not a substring grep): the key must exist AND be boolean
# true. A stale file carrying <false/> would otherwise pass while macOS still
# treats the entitlement as absent.
for key in com.apple.security.automation.apple-events; do
    value="$(/usr/libexec/PlistBuddy -c "Print :$key" "$ENT_PLIST" 2>/dev/null || true)"
    if [ "$value" != "true" ]; then
        echo "Error: signed binary entitlement '$key' is '${value:-absent}' (need true)." >&2
        echo "       Check that ENTITLEMENTS ('$ENTITLEMENTS') is the repo's" >&2
        echo "       Sources/CheThingsMCP/Entitlements.plist and contains the key as <true/>." >&2
        rm -f "$ENT_PLIST"
        exit 1
    fi
done
rm -f "$ENT_PLIST"
echo "  ✓ automation.apple-events entitlement present and true"

# Step 3: notarize (requires zip wrapper for raw Mach-O)
# Capture submission output so we can extract submission ID for post-mortem debug
# if the wait fails. notarytool prints "  id: <UUID>" line on success and failure.
echo ""
echo "[3/4] Submitting for notarization (this typically takes 1-15 minutes)..."
ZIP_PATH="$WORKDIR/notarize.zip"
ditto -c -k --keepParent "$BINARY" "$ZIP_PATH"

# tee output so user sees progress while we capture submission ID
SUBMIT_LOG="$WORKDIR/notarize.log"

# Helper: extract submission UUID from notarytool log; never aborts under set -e
# (grep returns 1 if no match → would abort; trailing || true makes it fail-soft)
extract_submission_id() {
    grep -m1 -E '^[[:space:]]*id:' "$1" 2>/dev/null | awk '{print $2}' || true
}

if ! xcrun notarytool submit "$ZIP_PATH" \
        --keychain-profile "$NOTARY_PROFILE" \
        --wait 2>&1 | tee "$SUBMIT_LOG"; then
    SUBMISSION_ID="$(extract_submission_id "$SUBMIT_LOG")"
    echo "" >&2
    echo "Error: notarization failed (or notarytool errored)." >&2
    if [[ -n "$SUBMISSION_ID" ]]; then
        echo "       To see Apple's rejection reason:" >&2
        echo "         xcrun notarytool log $SUBMISSION_ID --keychain-profile $NOTARY_PROFILE" >&2
    else
        echo "       (no submission ID captured — full notarytool output above; if format changed," >&2
        echo "        run: xcrun notarytool history --keychain-profile $NOTARY_PROFILE)" >&2
    fi
    exit 1
fi

# Do not rely on the exit code alone: man notarytool does not say what it returns for an
# Invalid or Rejected submission, and an unnotarized binary must not be packaged.
if ! grep -qE '^[[:space:]]*status:[[:space:]]*Accepted' "$SUBMIT_LOG"; then
    SUBMISSION_ID="$(extract_submission_id "$SUBMIT_LOG")"
    echo "" >&2
    echo "Error: notarization did not finish with 'status: Accepted'." >&2
    if [[ -n "$SUBMISSION_ID" ]]; then
        echo "       To see Apple's reason: xcrun notarytool log $SUBMISSION_ID --keychain-profile $NOTARY_PROFILE" >&2
    fi
    exit 1
fi

SUBMISSION_ID="$(extract_submission_id "$SUBMIT_LOG")"
if [[ -n "$SUBMISSION_ID" ]]; then
    echo "Submission ID: $SUBMISSION_ID"
else
    echo "(submission accepted but ID not captured — notarytool output format may have changed)"
fi

# Step 4: print final state for visual confirmation
# || true: this is informational only; if codesign output format changes and grep
# doesn't match, we don't want to fail the whole script.
echo ""
echo "[4/4] Final signature state:"
codesign -dv --verbose=2 "$BINARY" 2>&1 | grep -E "Authority|TeamIdentifier|flags|Signature" || true

echo ""
echo "=== sign-and-notarize: DONE ==="
echo "Note: stapling skipped (raw Mach-O binaries don't support stapler)."
echo "      A quarantined copy (for example a browser download) is checked online on first launch."
echo "      To verify notarization end-to-end: spctl -a -vvv -t install $BINARY"
