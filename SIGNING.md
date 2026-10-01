# Trusted Distribution

HTTPS downloads and SHA-256 checksums protect transport and detect changed files. They do not replace a verified publisher signature. Renaming the installer, making a self-signed certificate or disabling operating-system protection does not establish publisher trust.

The current preview has no distribution certificates. Do not advertise it as warning-free. Stable tags such as `v1.0.1` fail before publication unless both platforms pass signing verification. Only `-preview.` tags can publish unsigned prereleases.

## macOS

An Apple Developer Program account with Developer ID signing access is required. Apple Development certificates are not suitable for outside-store distribution.

Configure these repository Actions secrets, not source files or chat messages:

| Secret | Value |
| --- | --- |
| `MACOS_CERTIFICATES_P12` | Base64 PKCS#12 export containing Developer ID Application and Developer ID Installer identities with their private keys |
| `MACOS_CERTIFICATE_PASSWORD` | Export password |
| `MACOS_APP_IDENTITY` | Full `Developer ID Application: ...` identity |
| `MACOS_INSTALLER_IDENTITY` | Full `Developer ID Installer: ...` identity |
| `APPLE_ID` | Developer account Apple ID |
| `APPLE_TEAM_ID` | Developer team ID |
| `APPLE_APP_PASSWORD` | App-specific password for notarization, not the account login password |

The stable-release runner imports credentials into a temporary keychain. It signs and notarizes the app, staples its ticket before packaging, signs/notarizes the PKG and DMG, verifies their tickets, and checks Gatekeeper acceptance for the app and PKG. The keychain is removed after the job. Local builds may instead supply existing identities and `MACOS_NOTARY_PROFILE`, plus optional `MACOS_NOTARY_KEYCHAIN`; set `REQUIRE_SIGNING=1` to disallow unsigned output.

References: [Apple Developer ID](https://developer.apple.com/developer-id/), [Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Windows

A code-signing identity trusted by Windows is required. The configured path uses a CA-issued PKCS#12 certificate available for automated signing. Configure `WINDOWS_CERTIFICATE_P12` (base64) and `WINDOWS_CERTIFICATE_PASSWORD` as Actions secrets. The stable build forces signing and verifies Authenticode plus timestamps for the installer and packaged EXE, DLL and native Node modules.

Some providers keep keys in hardware or a cloud signing service rather than exportable PKCS#12 files. Those identities need the provider's signing integration; do not export keys contrary to the provider's policy. Electron-builder 26 supports Azure signing via `win.azureSignOptions`; configure the chosen service only after the publisher account exists.

A valid signature identifies the publisher and protects integrity. It does not guarantee immediate SmartScreen reputation for a new file, and managed-device policies can still block it. Microsoft Store distribution is a separate publication route, not something this repository claims to have completed.

References: [Microsoft SmartScreen reputation](https://learn.microsoft.com/en-us/windows/apps/package-and-deploy/smartscreen-reputation), [electron-builder 26 signing](https://www.electron.build/v26/docs/features/code-signing/).

## Release Procedure

1. Provision the publisher identities and configure secrets securely.
2. Update the application version and release notes to reflect actual signing status.
3. Run the installer tests on `main`.
4. Push a new stable version tag. Do not move an existing tag.
5. Confirm both platform jobs and signature checks pass before using the stable download links.

Never commit certificates, private keys, keychains, real journals or account passwords. No signing credentials are required by end users.
