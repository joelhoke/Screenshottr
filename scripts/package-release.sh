#!/bin/bash
set -euo pipefail

# Package an already notarized export. This script never publishes a release.
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ $# != 1 || ! -d "$1/Contents" ]]; then
    echo 'Usage: scripts/package-release.sh /path/to/notarized/Screenshottr.app' >&2
    exit 1
fi
source_app="$(cd "$1" && pwd)"
cd "$project_root"
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Screenshottr/Info.plist)"
if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo 'Set CFBundleShortVersionString to a three-part version before packaging.' >&2
    exit 1
fi

mkdir -p build dist
staging_dir="$(mktemp -d "$project_root/build/package.XXXXXX")"
output_dir="$project_root/dist/$version"
app="$staging_dir/Screenshottr.app"
archive_name="Screenshottr-$version-macOS.zip"
archive="$output_dir/$archive_name"
ditto "$source_app" "$app"

python3 - "$app/Contents/Info.plist" "$version" <<'CHECK'
import plistlib
import sys
with open(sys.argv[1], 'rb') as f:
    info = plistlib.load(f)
if (info.get('CFBundleIdentifier') != 'com.joelhoke.Screenshottr'
        or info.get('CFBundleShortVersionString') != sys.argv[2]
        or not info.get('LSUIElement')):
    raise SystemExit('Exported app metadata does not match this release.')
CHECK
codesign --verify --deep --strict "$app"
lipo "$app/Contents/MacOS/Screenshottr" -verify_arch arm64 x86_64
codesign -d --entitlements :- "$app" > "$staging_dir/entitlements.plist" 2>/dev/null
python3 - "$staging_dir/entitlements.plist" <<'CHECK'
import plistlib
import sys
from pathlib import Path
raw = Path(sys.argv[1]).read_bytes()
entitlements = plistlib.loads(raw) if raw.strip() else {}
if entitlements.get('com.apple.security.get-task-allow', False):
    raise SystemExit('Release must not include the debugger get-task-allow entitlement.')
CHECK
# Fail before writing distribution artifacts unless Apple's ticket is present and valid.
xcrun stapler validate "$app"
spctl --assess --type execute --verbose=2 "$app"
signing_note='Signed with Developer ID and notarized by Apple. The notarization ticket is included in the app.'

# Package only the app bundle, never certificates, local signing config, or build logs.
ditto -c -k --sequesterRsrc --keepParent "$app" "$staging_dir/$archive_name"
mkdir -p "$staging_dir/extracted"
ditto -x -k "$staging_dir/$archive_name" "$staging_dir/extracted"
codesign --verify --deep --strict "$staging_dir/extracted/Screenshottr.app"
xcrun stapler validate "$staging_dir/extracted/Screenshottr.app"
spctl --assess --type execute --verbose=2 "$staging_dir/extracted/Screenshottr.app"
mkdir -p "$output_dir"
mv "$staging_dir/$archive_name" "$archive"
(
    cd "$output_dir"
    shasum -a 256 "$archive_name" > SHA256SUMS.txt
)
cat > "$output_dir/release-notes.md" <<NOTES
<a href="https://github.com/joelhoke/Screenshottr/releases/download/v$version/$archive_name"><img src="https://raw.githubusercontent.com/joelhoke/Screenshottr/v$version/Screenshottr/Assets.xcassets/AppIcon.appiconset/AppIcon-256.png" alt="Download Screenshottr for Mac" width="112" height="112"></a>

## [Download Screenshottr for Mac ↓](https://github.com/joelhoke/Screenshottr/releases/download/v$version/$archive_name)

**macOS 13+ · Apple Silicon & Intel · Free**

Download the ZIP, unzip it, and drag Screenshottr into Applications.

Screenshottr $version — a lightweight Mac menu bar launcher for Apple’s screenshot and screen recording toolbar.

**Signing status:** $signing_note

### Download and install

1. Click **Download Screenshottr for Mac** above (or choose **$archive_name** from Assets). The automatically generated Source code downloads are for developers.
2. Unzip it and drag **Screenshottr.app** into **Applications**.
3. Open Screenshottr. Click the camera in your menu bar to open Apple’s capture toolbar; click the small dropdown to access Launch at Login and Quit.
4. When prompted, allow Screenshottr in **System Settings → Privacy & Security → Screen & System Audio Recording**. Follow any Quit & Reopen prompt.

### Included

- One-click access to Apple’s screenshot and recording controls.
- Apple’s selection, microphone, timer, preview, and save-location options.
- Optional Launch at Login; no Dock icon or main window.
- One universal app for Apple Silicon and Intel Macs; requires macOS 13 or later.

### Validation and limitations

- The packaged app contains arm64 and x86_64 code and passes code-signature verification after extraction.
- Functional testing has been on macOS 26.5.1; macOS 13 and Intel hardware remain untested.
- No custom onboarding, editor, added system-audio capture, or automatic updater.
- SHA256SUMS.txt is included for download verification.
NOTES
printf '\nPackage ready: %s\nRelease notes: %s\n' "$archive" "$output_dir/release-notes.md"
