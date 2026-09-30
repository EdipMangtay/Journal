# Verification

## macOS

- Existing analytics and persistence tests: `cd macos && bash Scripts/test-local.sh` on an Apple Silicon development Mac with Xcode and Command Line Tools.
- CI uses `xcodebuild test` with the shared Xcode scheme.
- Universal release build: `bash Scripts/package-release.sh 1.0.0`.
- The packaging script verifies both `arm64` and `x86_64`, validates the application signature, builds PKG and DMG, and writes SHA-256 checksums.
- Original application source files remain unchanged. Packaging uses the same unsandboxed storage location as `Scripts/build-local.sh`.
- The original asset catalog contains incorrect icon dimensions. Release packaging generates correctly sized icon representations from the existing artwork without changing the original assets.

## Windows

```powershell
cd windows
npm ci
npm test
npm run build
npm run test:e2e
```

The desktop test launches Electron with a fresh temporary journal, creates a setup and trade, edits and cancels, creates a review, verifies chart pixels, changes preferences, restarts, checks saved state, inspects desktop and narrow layouts, checks demo isolation, and deletes a test trade.

On GitHub's Windows runner the same test targets the installed executable after running the generated NSIS installer. The runner is disposable; local source-mode tests use a temporary data directory.

Core tests cover validation, analytics, CSV escaping and round trips, backup merging, cross-platform demo fixtures, time zones, write serialization, atomic persistence, corruption handling and backup preservation.

## Compatibility

`windows/tests/fixtures/macos-backup.json` contains only generated demo data exported by the original Swift app. `macos-metrics.json` contains the corresponding Swift calculations. `macos/Scripts/compatibility-fixture.swift` regenerates the files and can also decode and restore a Windows backup in a fresh SwiftData store.

## Limits

CI validates installation and application behavior; it cannot prove all physical machines or managed environments will accept unsigned installers. Intel Mac output is cross-compiled; testing on physical Intel hardware and the minimum supported macOS version remains a separate release check. Native OS fonts and file dialogs differ. No pixel-identical rendering guarantee is made across operating systems.
