# Installation / Kurulum

Download the installer from [GitHub Releases](https://github.com/EdipMangtay/Journal/releases/latest). Source ZIP downloads are for development, not installation.

## macOS 14 or newer

Download **Liquidity-Edge-macOS-Universal.pkg**, open it and complete Apple's Installer. The application is installed in `/Applications`. It contains both Apple Silicon and Intel builds; Xcode, Swift and Homebrew are not required. Alternatively, open the `.dmg` and drag the application onto Applications.

This release is ad-hoc signed, without an Apple Developer ID distribution signature or notarization. macOS may block its first launch or the installer. After checking the release and publisher, use **System Settings > Privacy & Security > Open Anyway** for that specific file. See [Apple's instructions](https://support.apple.com/102445). Do not disable Gatekeeper globally. Fully trusted distribution requires Developer ID Application and Installer certificates and Apple notarization.

The installer does not remove existing journal data. The original local app stores its journal in `~/Library/Application Support/LiquidityEdge/Journal.store`. Export a JSON backup before switching versions. Close a running copy before upgrading; use only one app copy at a time.

## Windows 10/11 (64-bit)

Download **Liquidity-Edge-Windows-Setup.exe** and open it. Installation is per-user, requires no administrator access and includes the entire runtime. Desktop and Start Menu shortcuts are created automatically. No Node.js, Python, Swift or separate dependency installation is needed. The app works offline after installation.

This release has no Windows code-signing certificate. Windows SmartScreen may show an unknown-publisher warning; verify the source before choosing **More info > Run anyway**. Managed devices may prohibit unsigned applications. A frictionless, trusted first launch cannot be guaranteed without distribution certificates.

Windows data is stored in `%APPDATA%/Liquidity Edge/journal.json`. Writes are atomic and the previous successful state is preserved as `journal.json.bak`. Uninstalling leaves journal data intact. Export JSON backups from Settings to move data between platforms. Imported backups merge by stable ID; they do not erase unrelated records.

## Turkce

- Mac: `.pkg` dosyasini indirip acin ve kurulum adimlarini tamamlayin. Intel ve Apple Silicon desteklenir. Alternatif olarak `.dmg` kullanilabilir.
- Windows: `Setup.exe` dosyasini indirip acin. Gerekli calistirma ortami kurulumun icindedir.
- Her iki platform da cevrimdisi calisir. Hesap ve bulut senkronizasyonu yoktur.
- Dagitim sertifikalari olmadigi icin ilk acilista guvenlik onayi gerekebilir. Guvenlik korumalarini tamamen kapatmayin.
- Guncelleme oncesi Settings ekranindan JSON yedegi alin. Platformlar arasi veri tasimak icin JSON export/import kullanin.

## Checksums

Each release includes SHA-256 checksums. On macOS run `shasum -a 256 <download>`. On Windows run `Get-FileHash <download> -Algorithm SHA256` in PowerShell and compare the result with the release checksum file.
