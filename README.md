# 🎥 HaoTube - Aplikasi Video Streaming

Aplikasi video streaming yang dibangun dengan Flutter untuk memberikan pengalaman menonton video yang mulus dan intuitif.



## ✨ Fitur Utama

- 🎬 **Streaming Video** - Putar video dari YouTube dengan kualitas terbaik
- 🔍 **Search Video** - Cari video favorit dengan mudah
- 📱 **Responsive Design** - Tampilan yang responsif di berbagai ukuran layar
- 🎨 **Modern UI** - Antarmuka yang clean dan user-friendly dengan desain Material Design 3
- 📺 **Fullscreen Mode** - Mode fullscreen untuk pengalaman menonton yang immersive

## 🛠️ Teknologi yang Digunakan

- **Framework**: Flutter 3.0+
- **Language**: Dart 3.0+
- **UI**: Material Design
- **Font**: Google Fonts (Poppins)
- **Video Player**: youtube_player_flutter

## 📦 Dependencies Utama

```yaml
- flutter: SDK utama
- google_fonts: ^6.1.0 - Font Google custom
- http: ^1.5.0 - HTTP client untuk API calls
- youtube_player_flutter: ^9.1.3 - YouTube player widget
- url_launcher: ^6.3.2 - Membuka URL eksternal
```

## 🚀 Cara Memulai

### Prerequisites
- Flutter SDK 3.0.0+
- Dart 3.0.0+
- Git

### Instalasi

1. Clone repository
```bash
git clone <repository-url>
cd haotube_working
```

2. Install dependencies
```bash
flutter pub get
```

3. Run aplikasi
```bash
flutter run
```

### Build untuk Production

**Android:**
```bash
flutter build apk
```

**iOS:**
```bash
flutter build ios
```

## 📁 Struktur Project

```
lib/
├── main.dart                 # Entry point aplikasi
├── screen/                   # UI screens
├── services/
│   └── youtube_service.dart  # YouTube API service
└── theme/
    └── colors.dart           # Color constants
```

## 🐛 Known Issues (Bug yang Diketahui)

### Video Pause/Repeat pada Fullscreen
Terdapat bug di mana video akan **pause atau terulang** ketika:
- ✋ **Masuk ke fullscreen mode**
- ✋ **Exit dari fullscreen mode**

**Status**: Dalam proses perbaikan  
**Affected**: youtube_player_flutter dependency  
**Workaround**: Refresh atau restart video playback jika mengalami issue

Jika Anda menemukan solusi atau memiliki suggestion, silakan buat **Issue** atau **Pull Request**.

## 🤝 Berkontribusi

Kontribusi sangat diterima! Berikut caranya:

1. Fork repository ini
2. Buat branch untuk fitur Anda (`git checkout -b feature/AmazingFeature`)
3. Commit perubahan (`git commit -m 'Add some AmazingFeature'`)
4. Push ke branch (`git push origin feature/AmazingFeature`)
5. Buat Pull Request

## 📝 Lisensi

Project ini berlisensi di bawah MIT License - lihat file LICENSE untuk detail.

## 📧 Kontak

Jika ada pertanyaan atau saran, silakan buat issue di repository ini.

---

**Developer**: Richky Sung  
**Last Updated**: December 29, 2025  
**Status**: Active Development 🔄
