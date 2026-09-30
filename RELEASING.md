# Publishing a release

Requires Xcode, a signed-in Apple Developer Program account, and a **Developer ID Application** certificate with its private key in Keychain. Configure `Signing.local.xcconfig` with that certificate's team. Keep certificates, keys, credentials, and local signing configuration out of Git.

1. Update `CFBundleShortVersionString` (three parts) and `CFBundleVersion` in `Screenshottr/Info.plist`. Run the tests described in README.md.
2. Archive a universal release with hardened runtime, a secure timestamp, and no debugger entitlement. Replace `1.0.0` in these commands when releasing another version.

   ```sh
   xcodebuild -project Screenshottr.xcodeproj -scheme Screenshottr \
     -configuration Release -derivedDataPath build/distribution \
     -archivePath build/archives/Screenshottr-1.0.0.xcarchive \
     'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
     ENABLE_HARDENED_RUNTIME=YES CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
     'CODE_SIGN_IDENTITY=Developer ID Application' \
     OTHER_CODE_SIGN_FLAGS=--timestamp archive
   ```

3. Create `build/ExportOptions.plist` with the following contents, replacing `YOUR_TEAM_ID` with your developer team ID:

   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
   <plist version="1.0"><dict>
     <key>method</key><string>developer-id</string>
     <key>destination</key><string>upload</string>
     <key>signingStyle</key><string>manual</string>
     <key>signingCertificate</key><string>Developer ID Application</string>
     <key>teamID</key><string>YOUR_TEAM_ID</string>
   </dict></plist>
   ```

4. Upload for notarization using the account already signed in to Xcode. This does not publish the app on GitHub or the App Store.

   ```sh
   xcodebuild -exportArchive \
     -archivePath build/archives/Screenshottr-1.0.0.xcarchive \
     -exportOptionsPlist build/ExportOptions.plist \
     -exportPath build/notarization -allowProvisioningUpdates
   ```

5. Export the notarized app. If Apple is still processing it, wait for acceptance in Xcode Organizer and retry this step. Do not re-upload merely because processing is pending. Use a fresh export directory for each release.

   ```sh
   xcodebuild -exportNotarizedApp \
     -archivePath build/archives/Screenshottr-1.0.0.xcarchive \
     -exportPath build/notarized -allowProvisioningUpdates
   scripts/package-release.sh build/notarized/Screenshottr.app
   ```

   The script validates the version, bundle identifier, menu-only setting, both architectures, signature, absence of debugger entitlement, notarization ticket, and Gatekeeper acceptance. It checks the extracted ZIP again before writing `dist/<version>/` with the app ZIP, SHA-256 checksum, and release notes. It does not publish anything.

6. Review the release notes and verification record. Commit the release changes, tag that commit `v1.0.0`, and push the commit and tag. Create a GitHub draft with the app ZIP and `SHA256SUMS.txt` attached:

   ```sh
   gh release create v1.0.0 --verify-tag --draft \
     --title 'Screenshottr 1.0.0' \
     --notes-file dist/1.0.0/release-notes.md \
     dist/1.0.0/Screenshottr-1.0.0-macOS.zip dist/1.0.0/SHA256SUMS.txt
   ```

7. Check the draft, then publish with `gh release edit v1.0.0 --draft=false --latest`. Download the published assets into a new directory, check `shasum -a 256 -c SHA256SUMS.txt`, extract the app, and repeat `codesign --verify --deep --strict`, `xcrun stapler validate`, and `spctl --assess --type execute --verbose=2` against that downloaded app. Confirm the public `/releases/latest` link resolves to the new release before sharing it.

Apple documents the [Developer ID distribution workflow](https://help.apple.com/xcode/mac/current/en.lproj/dev033e997ca.html) and [notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).
