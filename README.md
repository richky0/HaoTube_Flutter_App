#  HaoTube - Video Streaming Application

A video streaming application built with Flutter to deliver a smooth and intuitive video watching experience.

##  Main Features

-  **Video Streaming** - Play videos from YouTube with the best quality
-  **Video Search** - Easily search for favorite videos
-  **Responsive Design** - Responsive display across various screen sizes
-  **Modern UI** - Clean and user-friendly interface with Material Design 3
-  **Fullscreen Mode** - Immersive fullscreen viewing experience

##  Technologies Used

- **Framework**: Flutter 3.0+
- **Language**: Dart 3.0+
- **UI**: Material Design
- **Font**: Google Fonts (Poppins)
- **Video Player**: youtube_player_flutter

##  Main Dependencies

```yaml
- flutter: Main SDK
- google_fonts: ^6.1.0 - Custom Google fonts
- http: ^1.5.0 - HTTP client for API calls
- youtube_player_flutter: ^9.1.3 - YouTube player widget
- url_launcher: ^6.3.2 - Open external URLs
```

##  Getting Started

### Prerequisites
- Flutter SDK 3.0.0+
- Dart 3.0.0+
- Git

### Installation

1. Clone repository
```bash
cd haotube_working
```

2. Install dependencies
```bash
flutter pub get
```

3. Run the application
```bash
flutter run
```

### Build for Production

**Android:**
```bash
flutter build apk
```

**iOS:**
```bash
flutter build ios
```

##  Project Structure

```
lib/
├── main.dart                 # Application entry point
├── screen/                   # UI screens
├── services/
│   └── youtube_service.dart  # YouTube API service
└── theme/
    └── colors.dart           # Color constants
```

##  Known Issues

### Video Pause/Repeat in Fullscreen Mode
There is a bug where video will **pause or repeat** when:
-  **Entering fullscreen mode**
-  **Exiting fullscreen mode**

**Status**: Currently being fixed  
**Affected**: youtube_player_flutter dependency  
**Workaround**: Refresh or restart video playback if experiencing the issue

If you find a solution or have suggestions, please create an **Issue** or **Pull Request**.

##  Contributing

Contributions are highly welcome! Here's how:

1. Fork this repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Create a Pull Request

##  License

This project is licensed under the MIT License - see the LICENSE file for details.

##  Contact

If you have any questions or suggestions, please create an issue in this repository.

---

**Developer**: Richky Sung  
**Last Updated**: December 29, 2025
