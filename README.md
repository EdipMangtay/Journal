# LIQUIDITY EDGE / Trading Journal

macOS ve Windows için profesyonel çevrimdışı (offline) işlem günlüğü. İşlemler, performans analitiği, seans takvimi, strateji rehberi (playbook), canlı periyot değerlendirmeleri, görsel grafik notları ve taşınabilir JSON yedekleme.

## Hazır Kurulum Dosyaları (İndir)

Doğrudan aşağıdaki resmi kurulum dosyalarından birini indirin. Kaynak kodu zip dosyasını indirmeyin; kurulum paketleri tüm çalışma ortamını içerir.

- 🪟 **Windows Kurulumu (EXE):** [Liquidity-Edge-Windows-Setup.exe](https://github.com/EdipMangtay/Journal/releases/download/v1.1.0-preview.1/Liquidity-Edge-Windows-Setup.exe) *(117.58 MB — Windows 10/11 x64)*
- 🍏 **macOS Kurulum Paketi (PKG):** [Liquidity-Edge-macOS-Universal.pkg](https://github.com/EdipMangtay/Journal/releases/download/v1.1.0-preview.1/Liquidity-Edge-macOS-Universal.pkg) *(2.74 MB — Apple Silicon & Intel)*
- 💿 **macOS Alternatif (DMG):** [Liquidity-Edge-macOS-Universal.dmg](https://github.com/EdipMangtay/Journal/releases/download/v1.1.0-preview.1/Liquidity-Edge-macOS-Universal.dmg) *(3.23 MB — Sürükle & Bırak)*
- 📦 **Tüm Sürümler ve Dosyalar:** [Liquidity Edge v1.1.0-preview.1 Release Sayfası](https://github.com/EdipMangtay/Journal/releases/tag/v1.1.0-preview.1)

| Platform | Kurulum Paketi | Boyut | Gereksinimler |
| --- | --- | --- | --- |
| **Windows 10 / 11** | [Liquidity-Edge-Windows-Setup.exe](https://github.com/EdipMangtay/Journal/releases/download/v1.1.0-preview.1/Liquidity-Edge-Windows-Setup.exe) | 117.58 MB | 64-bit Windows, ek yazılım gerektirmez |
| **macOS (PKG)** | [Liquidity-Edge-macOS-Universal.pkg](https://github.com/EdipMangtay/Journal/releases/download/v1.1.0-preview.1/Liquidity-Edge-macOS-Universal.pkg) | 2.74 MB | macOS 14+, Apple Silicon veya Intel |
| **macOS (DMG)** | [Liquidity-Edge-macOS-Universal.dmg](https://github.com/EdipMangtay/Journal/releases/download/v1.1.0-preview.1/Liquidity-Edge-macOS-Universal.dmg) | 3.23 MB | Uygulamalar (Applications) klasörüne sürükleyin |

Kurulum paketleri uygulamanın çalışması için gereken tüm bileşenleri içerir. Ek bir geliştirici aracı veya çalışma ortamı kurmanıza gerek yoktur. Dosyaları kaynak kodu ZIP'inden değil, **Releases** bölümünden indiriniz.

**Güvenlik bildirimi:** Önizleme paketleri açık kaynak olarak derlenmiş olup kurumsal sertifika imzası içermediğinden ilk açılışta macOS Gatekeeper veya Windows SmartScreen onay ekranı gösterebilir. Detaylar için [SIGNING.md](SIGNING.md) ve [INSTALLATION.md](INSTALLATION.md) kılavuzuna bakınız.

Yeni kurulumlar tertemiz, boş bir günlükle açılır; hiçbir demo işlem veya görsel otomatik yüklenmez. Kullanıcı kendi işlemlerini girer ve tüm veriler yerel olarak kullanıcının kendi bilgisayarında depolanır.

![macOS dashboard](docs/images/macos-dashboard.png)

## Platformlar ve Özellikler

- `macos/`: Orijinal tasarımı ve performansı koruyan yerel SwiftUI / SwiftData / Swift Charts uygulaması.
- `windows/`: Özgün Mac tasarımını, renk paletini, oranlarını ve işlevlerini birebir sunan Electron masaüstü uygulaması.
- **Tam Türkçe:** Arayüz, finansal metrikler, model kuralları, filtreler ve hata bildirimleri eksiksiz Türkçe olarak hazırlanmıştır.
- **Görsel Not Düzenleyici:** Grafik ekran görüntüleri üzerinde yakınlaştırma (zoom), kaydırma (pan), ok çizimi, dikdörtgen alanı, metin ve likidite seviyesi etiketleme imkanı sunar.
- **Gizlilik ve Güvenlik:** Tamamen yerel ve çevrimdışıdır. İnternet bağlantısı, hesap kaydı ya da veri toplama/telemetri yoktur.
- **Taşınabilirlik:** Sürüm 1 uyumlu JSON yedekleme ile verilerinizi Mac ve Windows arasında istediğiniz zaman kayıpsız aktarabilirsiniz.

## Geliştirme ve Testler

### macOS
```bash
cd macos
bash Scripts/test-local.sh
bash Scripts/package-release.sh 1.1.0
```

### Windows
```powershell
cd windows
npm ci
npm test
npm run test:e2e
npm run dist:win
```

## Doğrulama

GitHub Actions iş akışı her iki platformu otomatik olarak derler, tüm yerel SwiftData ve JavaScript testlerini icra eder, Windows EXE ve macOS PKG/DMG paketlerinin kurulum ve ilk açılış testlerini başarıyla tamamlar.
