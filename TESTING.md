# Verification

## macOS

- Existing analytics and persistence tests: `cd macos && bash Scripts/test-local.sh` on an Apple Silicon development Mac with Xcode and Command Line Tools.
- CI uses `xcodebuild test` with the shared Xcode scheme.
- Universal release build: `bash Scripts/package-release.sh 1.0.1`.
- The packaging script verifies both `arm64` and `x86_64`, validates the application signature, builds PKG and DMG, and writes SHA-256 checksums.
- The original working application is not modified. The distribution copy changes first launch to open an empty journal. Packaging uses the same unsandboxed storage location as `Scripts/build-local.sh`.
- A fresh-store test verifies no trades, setups, reviews or screenshots are created, including after exploring the isolated demo. Installer GUI smoke tests use `JOURNAL_TEST_DATA_DIR` and verify a real local store is created; they never open the user's personal store.
- The original asset catalog contains incorrect icon dimensions. Release packaging generates correctly sized icon representations from the existing artwork without changing the original assets.

## Windows

```powershell
cd windows
npm ci
npm test
npm run build
npm run test:e2e
```

The desktop test launches Electron with a nonexistent temporary profile directory and verifies an empty first launch. It explicitly opens the optional demo, creates a setup and trade in the real journal, edits and cancels, creates a review, verifies chart pixels, changes preferences, restarts, checks saved state, inspects desktop and narrow layouts, checks demo isolation, and deletes a test trade.

On GitHub's Windows runner the same test targets the installed executable after running the generated NSIS installer. The runner is disposable; local source-mode tests use a temporary data directory.

Core tests cover validation, analytics, CSV escaping and round trips, backup merging, cross-platform demo fixtures, time zones, write serialization, atomic persistence, corruption handling and backup preservation.

A controlled-clock UI regression verifies a pending search update cannot reset a Settings form after navigation. Settings tests wait for the save confirmation and verify the on-disk value before relaunch. Storage tests cover reads during pending validation/writes and queue recovery after rejected validation.

## Compatibility

`windows/tests/fixtures/macos-backup.json` contains only generated demo data exported by the original Swift app. `macos-metrics.json` contains the corresponding Swift calculations. `macos/Scripts/compatibility-fixture.swift` regenerates the files and can also decode and restore a Windows backup in a fresh SwiftData store.

## Limits

Stable tag builds require trusted signing credentials. Windows checks Authenticode and timestamps for the installer and packaged executable/native modules; macOS verifies Developer ID signatures and stapled notarization tickets. These signing paths cannot be exercised without publisher credentials. Preview builds are explicitly unsigned and never promoted to stable by the workflow.

CI validates installation and application behavior; it cannot prove all physical machines or managed environments will accept unsigned installers. Intel Mac output is cross-compiled; testing on physical Intel hardware and the minimum supported macOS version remains a separate release check. Native OS fonts and file dialogs differ. No pixel-identical rendering guarantee is made across operating systems.
