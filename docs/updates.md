# Automatic updates (Sparkle)

The apps update themselves with [Sparkle 2](https://sparkle-project.org). Kit holds the shared pieces:

- `MacToolsUpdates` (Swift): `AppUpdater` (one `SPUStandardUpdaterController`), `CheckForUpdatesButton`,
  `AppUpdater.shared.menuItem()` and `AppUpdateSettings` (the Updates section for a settings form).
- `tools/embed-sparkle.sh`: puts Sparkle.framework in the app and signs its helpers.
- `tools/release-app.sh`: with `APPCAST` and `DMG_URL` set, signs the DMG for Sparkle and writes the appcast.
- `tools/fetch-sparkle.sh`: Sparkle's command-line tools (pinned version and sha256) into `tools/sparkle/`.
- `tools/appcast.py`: adds a release to an appcast (`appcast.py --self-check` tests it).

Sparkle's version is pinned in two places: `Package.swift` and `tools/fetch-sparkle.sh`. Change both together.

## The signing key

One EdDSA key signs every app's updates. `generate_keys` keeps the private key in the login keychain of the Mac
that makes releases; a copy lives in the password manager. On a new Mac, import it with
`tools/sparkle/bin/generate_keys -f <file>` (then delete the file). The public key is:

```
xSzU+UV/BhusD16KFG4/N+o/hcfAOiLS+rGWVKcmtyw=
```

If the private key is lost, installed copies can't take signed updates any more; they would need a manual download.

## Adding updates to an app

1. **Package.swift**: add `.product(name: "MacToolsUpdates", package: kitPackage)` to the app target.
2. **Info.plist**:
   ```xml
   <key>SUFeedURL</key>
   <string>https://newitools.app/<page>/appcast.xml</string>
   <key>SUPublicEDKey</key>
   <string>xSzU+UV/BhusD16KFG4/N+o/hcfAOiLS+rGWVKcmtyw=</string>
   <key>SUEnableAutomaticChecks</key>
   <true/>
   <key>SUScheduledCheckInterval</key>
   <integer>86400</integer>
   ```
   `CFBundleVersion` is what Sparkle compares: raise it with every release (1, 2, 3...).
3. **Launch**: `AppUpdater.start()` in `applicationDidFinishLaunching` (not in self-check or preview paths).
4. **Menu**: "Check for Updates…" under the app name.
   - SwiftUI: `CommandGroup(after: .appInfo) { CheckForUpdatesButton() }`
   - AppKit: `appMenu.addItem(AppUpdater.shared.menuItem())` after About.
   - Menu bar or accessory apps: put it in the status or right-click menu.
5. **Settings**: `AppUpdateSettings()` inside a grouped `Form`. Apps with their own row style build the rows from
   `AppUpdater.shared` (`automaticallyChecks`, `automaticallyDownloads`, `lastCheckedText`, `canCheck`, `checkNow()`).
6. **build.sh**: after the executable and Info.plist are in the bundle, before the app is signed:
   ```sh
   KIT=../Kit; [ -d "$KIT" ] || KIT=.build/checkouts/mac-tools-kit
   "$KIT/tools/embed-sparkle.sh" "$APP" "$IDENTITY"             # development builds
   "$KIT/tools/embed-sparkle.sh" "$APP" "$IDENTITY" --release   # Developer ID builds (adds --timestamp)
   ```
   It copies `.build/release/Sparkle.framework` to `Contents/Frameworks`, adds the
   `@executable_path/../Frameworks` rpath, and signs Installer.xpc, Downloader.xpc, Autoupdate, Updater.app and
   the framework, inside-out, with the hardened runtime. Sign the app afterwards without `--deep`.
7. **Check**: `codesign --verify --deep --strict build/<App>.app`, run the app's self-check from inside the bundle
   (`build/<App>.app/Contents/MacOS/<App> --self-check`, which loads the embedded framework), and render the
   settings page.

## Releasing

```sh
./build.sh --release
APPCAST=../newitools-site/<page>/appcast.xml \
DMG_URL=https://github.com/<owner>/<repo>/releases/download/v1.2.3/<App>-1.2.3.dmg \
RELEASE_NOTES_URL=https://github.com/<owner>/<repo>/releases/tag/v1.2.3 \
  ../Kit/tools/release-app.sh build/<App>.app dist
```

- Before notarizing, it checks that the app's `SUPublicEDKey` matches the key in the keychain.
- After the stapled DMG is ready, it runs `sign_update` on it and adds an item to the appcast (build number, version,
  date, minimum macOS from `LSMinimumSystemVersion`, the DMG's URL, length and EdDSA signature). Re-running for the
  same build replaces that item.
- `DMG_URL` is where the DMG will be served: a GitHub release asset, or a file on the site
  (e.g. `https://newitools.app/<page>/download/<App>-1.2.3.dmg`).
- `RELEASE_NOTES="<p>…</p>"` puts notes inline instead of a link.

Then publish in this order: upload the DMG (e.g. `gh release create v1.2.3 dist/<App>-1.2.3.dmg`), then deploy
the site with the new appcast. An appcast that points at a missing DMG shows users a failed download.
