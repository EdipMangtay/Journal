# Liquidity Edge for Mac and Windows

Download an installer below, not the source-code ZIP.

- Windows 10/11 x64: **Liquidity-Edge-Windows-Setup.exe**. Includes the runtime; no developer tools are required.
- Mac, macOS 14+: **Liquidity-Edge-macOS-Universal.pkg**. Supports Intel and Apple Silicon.
- Mac alternative: **Liquidity-Edge-macOS-Universal.dmg**. Drag Liquidity Edge to Applications.

The Mac application preserves the original native UI. Windows follows the same layout and includes the complete trade model, analytics, playbooks, reviews, screenshots and annotation editor. JSON backups are portable between platforms. Personal records are not included.

Verification includes native and JavaScript tests, installing and launching the Windows EXE, reinstall/uninstall data preservation, installing and launching the Mac PKG, and launching the app distributed in the DMG.

Version 1.0.1 opens a blank local journal on both platforms. No sample trades, setups, reviews or screenshots appear automatically. Records are saved only on the user's computer and survive relaunch. Existing journals are not erased; the optional demo remains separate.

Windows explicitly creates its journal folder before startup, reports startup failures, and is tested with no pre-existing data directory. Mac and Windows installer version numbers are kept in sync. Stable release publication now requires validated publisher signatures and Apple notarization; tags containing `-preview.` remain clearly marked unsigned prereleases.

**First-run security notice:** these files do not have Apple Developer ID notarization or a Windows distribution certificate. macOS and Windows may ask for approval or block unsigned software under managed-device policies. This is separate from application functionality. Follow [INSTALLATION.md](https://github.com/EdipMangtay/Journal/blob/main/INSTALLATION.md); do not disable operating-system security protections globally. Back up existing journal data before upgrading.

SHA-256 checksum files accompany the installers.
