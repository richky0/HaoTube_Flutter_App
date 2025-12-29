import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'services/youtube_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HaoTube',
      theme: ThemeData(
        primaryColor: const Color(0xFF1a73e8),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1a73e8),
          secondary: Color(0xFFfbbc04),
          surface: Color(0xFFf8f9fa),
        ),
        scaffoldBackgroundColor: const Color(0xFFf8f9fa),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF1a73e8),
          unselectedItemColor: Color(0xFF5f6368),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// VIDEO PLAYER MANAGER - Pendekatan Singleton
class VideoPlayerManager {
  static final VideoPlayerManager _instance = VideoPlayerManager._internal();
  factory VideoPlayerManager() => _instance;
  VideoPlayerManager._internal();

  YoutubePlayerController? _controller;
  bool _isMiniPlayerVisible = false;
  bool _isPlaying = false;
  bool _isFullscreen = false;
  String? _currentVideoId;
  String? _currentVideoTitle;
  Duration? _lastPosition;

  // Callbacks untuk UI update
  VoidCallback? _onStateChanged;

  YoutubePlayerController? get controller => _controller;
  bool get isMiniPlayerVisible => _isMiniPlayerVisible;
  bool get isPlaying => _isPlaying;
  bool get isFullscreen => _isFullscreen;
  String? get currentVideoId => _currentVideoId;
  String? get currentVideoTitle => _currentVideoTitle;
  Duration? get lastPosition => _lastPosition;

  void setOnStateChanged(VoidCallback callback) {
    _onStateChanged = callback;
  }

  void _notifyListeners() {
    _onStateChanged?.call();
  }

  void initializeController(String videoId, String videoTitle) {
    if (_controller != null && _currentVideoId == videoId) {
      return; // Controller sudah ada untuk video ini
    }

    // Dispose controller lama jika ada
    _controller?.dispose();

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        forceHD: false,
        hideControls: false,
        controlsVisibleAtStart: true,
        enableCaption: false,
        isLive: false,
      ),
    );

    _currentVideoId = videoId;
    _currentVideoTitle = videoTitle;
    _isPlaying = true;
    _isFullscreen = false;

    // Setup listener untuk update state
    _controller!.addListener(() {
      if (_controller!.value.isPlaying != _isPlaying) {
        _isPlaying = _controller!.value.isPlaying;
        _notifyListeners();
      }
    });

    _notifyListeners();
  }

  void saveCurrentPosition() {
    if (_controller != null) {
      _lastPosition = _controller!.value.position;
    }
  }

  void restorePosition() {
    if (_controller != null && _lastPosition != null) {
      _controller!.seekTo(_lastPosition!);
    }
  }

  void showMiniPlayer() {
    _isMiniPlayerVisible = true;
    _notifyListeners();
  }

  void hideMiniPlayer() {
    _isMiniPlayerVisible = false;
    _notifyListeners();
  }

  void togglePlayPause() {
    if (_controller != null) {
      if (_isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _isPlaying = !_isPlaying;
      _notifyListeners();
    }
  }

  void enterFullscreen() {
    _isFullscreen = true;
    saveCurrentPosition();
    _notifyListeners();
  }

  void exitFullscreen() {
    _isFullscreen = false;
    saveCurrentPosition();
    _notifyListeners();
  }

  void disposeController() {
    _controller?.dispose();
    _controller = null;
    _currentVideoId = null;
    _currentVideoTitle = null;
    _isPlaying = false;
    _isFullscreen = false;
    _lastPosition = null;
    _notifyListeners();
  }
}

// Singleton instance
final videoPlayerManager = VideoPlayerManager();

// FULLSCREEN VIDEO PLAYER SCREEN - Versi Sederhana
class FullscreenVideoPlayer extends StatefulWidget {
  final String videoId;
  final String videoTitle;

  const FullscreenVideoPlayer({
    super.key,
    required this.videoId,
    required this.videoTitle,
  });

  @override
  State<FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  bool _isTitleVisible = false;
  Timer? _titleTimer;

  @override
  void initState() {
    super.initState();

    // Set fullscreen state
    videoPlayerManager.enterFullscreen();

    // Setup fullscreen orientation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _enterFullscreen();
    });

    _showTitleTemporarily();
  }

  void _enterFullscreen() {
    // Set landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Hide system UI completely
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  void _exitFullscreen() {
    // Restore portrait orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
  }

  void _showTitleTemporarily() {
    setState(() {
      _isTitleVisible = true;
    });

    _titleTimer?.cancel();
    _titleTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isTitleVisible = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _titleTimer?.cancel();
    _exitFullscreen();
    videoPlayerManager.exitFullscreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _handleExit();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () {
            _showTitleTemporarily();
          },
          child: Stack(
            children: [
              // YOUTUBE PLAYER
              Center(
                child: YoutubePlayer(
                  controller: videoPlayerManager.controller!,
                  aspectRatio: 16 / 9,
                  showVideoProgressIndicator: true,
                  progressIndicatorColor: const Color(0xFF1a73e8),
                  progressColors: const ProgressBarColors(
                    playedColor: Color(0xFF1a73e8),
                    handleColor: Color(0xFF1a73e8),
                    bufferedColor: Colors.grey,
                    backgroundColor: Colors.grey,
                  ),
                  onReady: () {
                    // Restore position jika ada
                    if (videoPlayerManager.lastPosition != null) {
                      videoPlayerManager.controller!.seekTo(
                        videoPlayerManager.lastPosition!,
                      );
                    }
                  },
                  bottomActions: [
                    CurrentPosition(),
                    ProgressBar(
                      isExpanded: true,
                      colors: const ProgressBarColors(
                        playedColor: Color(0xFF1a73e8),
                        handleColor: Color(0xFF1a73e8),
                      ),
                    ),
                    RemainingDuration(),
                    IconButton(
                      icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                      onPressed: () {
                        _handleExit();
                      },
                    ),
                  ],
                ),
              ),

              // BACK BUTTON
              if (_isTitleVisible)
                Positioned(
                  top: 10,
                  left: 10,
                  child: GestureDetector(
                    onTap: () {
                      _handleExit();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),

              // VIDEO TITLE
              if (_isTitleVisible)
                Positioned(
                  top: 10,
                  left: 60,
                  right: 60,
                  child: Center(
                    child: Text(
                      widget.videoTitle,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleExit() {
    videoPlayerManager.saveCurrentPosition();
    Navigator.of(context).pop();
  }
}

// YOUTUBE PLAYER WIDGET
class YouTubePlayerWidget extends StatefulWidget {
  final String videoId;
  final String videoTitle;
  final bool autoPlay;

  const YouTubePlayerWidget({
    super.key,
    required this.videoId,
    required this.videoTitle,
    this.autoPlay = true,
  });

  @override
  State<YouTubePlayerWidget> createState() => _YouTubePlayerWidgetState();
}

class _YouTubePlayerWidgetState extends State<YouTubePlayerWidget> {
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();

    // Initialize or reuse controller
    if (videoPlayerManager.controller == null ||
        videoPlayerManager.currentVideoId != widget.videoId) {
      videoPlayerManager.initializeController(widget.videoId, widget.videoTitle);
    } else {
      // Restore position jika kembali dari fullscreen
      videoPlayerManager.restorePosition();
    }

    // Show miniplayer
    videoPlayerManager.showMiniPlayer();

    // Simulate loading
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _retryLoading() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    videoPlayerManager.controller!.load(widget.videoId);

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  void _enterFullscreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenVideoPlayer(
          videoId: widget.videoId,
          videoTitle: widget.videoTitle,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: _buildPlayerContent(),
    );
  }

  Widget _buildPlayerContent() {
    if (_hasError) {
      return _buildErrorState();
    }

    if (_isLoading || videoPlayerManager.controller == null) {
      return _buildLoadingState();
    }

    return YoutubePlayer(
      controller: videoPlayerManager.controller!,
      aspectRatio: 16 / 9,
      showVideoProgressIndicator: true,
      progressIndicatorColor: const Color(0xFF1a73e8),
      progressColors: const ProgressBarColors(
        playedColor: Color(0xFF1a73e8),
        handleColor: Color(0xFF1a73e8),
        bufferedColor: Colors.grey,
        backgroundColor: Colors.grey,
      ),
      bottomActions: [
        CurrentPosition(),
        ProgressBar(
          isExpanded: true,
          colors: const ProgressBarColors(
            playedColor: Color(0xFF1a73e8),
            handleColor: Color(0xFF1a73e8),
          ),
        ),
        RemainingDuration(),
        IconButton(
          icon: const Icon(Icons.fullscreen, color: Colors.white),
          onPressed: _enterFullscreen,
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color(0xFF1a73e8),
            ),
            const SizedBox(height: 16),
            Text(
              'Memuat video...',
              style: GoogleFonts.poppins(
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 50,
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat video',
              style: GoogleFonts.poppins(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _retryLoading,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1a73e8),
              ),
              child: const Text(
                'Coba Lagi',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// VIDEO THUMBNAIL
class VideoThumbnail extends StatelessWidget {
  final String thumbnailUrl;
  final String duration;

  const VideoThumbnail({
    super.key,
    required this.thumbnailUrl,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            image: DecorationImage(
              image: NetworkImage(thumbnailUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              duration,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// MAIN SCREEN
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late Future<List<YouTubeVideo>> _videosFuture;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _searchFocusNode.addListener(_onSearchFocusChanged);

    // Setup listener untuk video player manager
    videoPlayerManager.setOnStateChanged(() {
      if (mounted) setState(() {});
    });
  }

  void _onSearchFocusChanged() {
    if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _loadVideos() {
    _videosFuture = YouTubeService.getRandomPopularVideos();
  }

  void _refreshVideos() {
    setState(() {
      _loadVideos();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar() : _buildNormalAppBar(),
      body: Stack(
        children: [
          _currentIndex == 0
              ? HomeScreen(
            videosFuture: _videosFuture,
            onRefresh: _refreshVideos,
          )
              : _buildLibraryScreen(),

          // MINI PLAYER
          if (videoPlayerManager.isMiniPlayerVisible &&
              videoPlayerManager.controller != null &&
              !videoPlayerManager.isFullscreen)
            Positioned(
              bottom: 80,
              right: 16,
              child: _buildMiniPlayer(),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildLibraryScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Koleksi Video',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Fitur akan segera hadir',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Beranda',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.video_library_outlined),
          activeIcon: Icon(Icons.video_library),
          label: 'Koleksi',
        ),
      ],
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      title: Row(
        children: [
          Text(
            'HaoTube',
            style: GoogleFonts.poppins(
              color: const Color(0xFF1a73e8),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.play_circle_fill,
            color: Color(0xFFfbbc04),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.black),
          onPressed: () {
            setState(() {
              _isSearching = true;
            });
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _searchFocusNode.requestFocus();
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.black),
          onPressed: _refreshVideos,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () {
          setState(() {
            _isSearching = false;
            _searchController.clear();
          });
        },
      ),
      title: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFf8f9fa),
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: 'Cari di HaoTube...',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
              onPressed: () {
                _searchController.clear();
              },
            )
                : null,
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _navigateToSearchScreen(value);
            }
          },
          onChanged: (value) {
            setState(() {});
          },
        ),
      ),
      actions: [
        if (_searchController.text.isNotEmpty)
          TextButton(
            onPressed: () {
              _navigateToSearchScreen(_searchController.text);
            },
            child: Text(
              'CARI',
              style: GoogleFonts.poppins(
                color: const Color(0xFF1a73e8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  void _navigateToSearchScreen(String query) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(searchQuery: query),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchController.clear();
        });
      }
    });
  }

  Widget _buildMiniPlayer() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoDetailScreen(
              video: YouTubeVideo(
                id: videoPlayerManager.currentVideoId!,
                title: videoPlayerManager.currentVideoTitle ?? 'Video',
                thumbnailUrl: '',
                channelTitle: '',
                viewCount: '',
                publishedAt: '',
                description: '',
                duration: '',
                likeCount: '',
              ),
            ),
          ),
        );
      },
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 140,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Placeholder background
                Container(
                  color: Colors.grey[800],
                  child: Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white.withOpacity(0.7),
                      size: 40,
                    ),
                  ),
                ),

                // PLAY/PAUSE BUTTON
                Positioned.fill(
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        videoPlayerManager.togglePlayPause();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          videoPlayerManager.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),

                // VIDEO TITLE
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Text(
                    videoPlayerManager.currentVideoTitle ?? 'Video',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // CLOSE BUTTON
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      videoPlayerManager.hideMiniPlayer();
                      videoPlayerManager.disposeController();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// HOME SCREEN
class HomeScreen extends StatelessWidget {
  final Future<List<YouTubeVideo>> videosFuture;
  final VoidCallback onRefresh;

  const HomeScreen({
    super.key,
    required this.videosFuture,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        onRefresh();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: FutureBuilder<List<YouTubeVideo>>(
        future: videosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingIndicator();
          }

          if (snapshot.hasError) {
            return _buildErrorWidget(snapshot.error.toString());
          }

          final videos = snapshot.data ?? [];

          if (videos.isEmpty) {
            return _buildEmptyVideos();
          }

          return _buildVideoList(videos, context);
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF1a73e8),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat video trending dari YouTube...',
            style: GoogleFonts.poppins(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Color(0xFF1a73e8),
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat video trending',
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1a73e8),
                foregroundColor: Colors.white,
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyVideos() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Tidak ada video trending',
            style: TextStyle(
              color: Colors.black,
              fontSize: 18,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Coba refresh atau periksa koneksi internet',
            style: TextStyle(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList(List<YouTubeVideo> videos, BuildContext context) {
    return ListView.builder(
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return VideoCard(video: video);
      },
    );
  }
}

// VIDEO CARD
class VideoCard extends StatelessWidget {
  final YouTubeVideo video;

  const VideoCard({
    super.key,
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoDetailScreen(video: video),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VideoThumbnail(
              thumbnailUrl: video.thumbnailUrl,
              duration: video.duration,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFfbbc04).withOpacity(0.2),
                    child: Text(
                      video.channelTitle.isNotEmpty
                          ? video.channelTitle[0]
                          : 'Y',
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${video.channelTitle} • ${_formatViewCount(video.viewCount)} views • ${_formatTimeAgo(video.publishedAt)}',
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatViewCount(String viewCount) {
    final count = int.tryParse(viewCount) ?? 0;
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatTimeAgo(String publishedAt) {
    try {
      final date = DateTime.parse(publishedAt);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()} tahun lalu';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()} bulan lalu';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} hari lalu';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} jam lalu';
      } else {
        return 'Baru saja';
      }
    } catch (e) {
      return 'Beberapa waktu lalu';
    }
  }
}

// VIDEO DETAIL SCREEN
class VideoDetailScreen extends StatefulWidget {
  final YouTubeVideo video;

  const VideoDetailScreen({
    super.key,
    required this.video,
  });

  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize video player
    videoPlayerManager.initializeController(widget.video.id, widget.video.title);
    videoPlayerManager.showMiniPlayer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf8f9fa),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'HaoTube',
          style: GoogleFonts.poppins(
            color: const Color(0xFF1a73e8),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // YOUTUBE PLAYER
            YouTubePlayerWidget(
              videoId: widget.video.id,
              videoTitle: widget.video.title,
              autoPlay: true,
            ),

            // VIDEO INFO
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video.title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${_formatViewCount(widget.video.viewCount)} views',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimeAgo(widget.video.publishedAt),
                        style: GoogleFonts.poppins(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFfbbc04).withOpacity(0.2),
                        radius: 20,
                        child: Text(
                          widget.video.channelTitle.isNotEmpty
                              ? widget.video.channelTitle[0]
                              : 'C',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.video.channelTitle,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Channel',
                              style: GoogleFonts.poppins(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Subscribe'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // DESCRIPTION
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.video.description.isNotEmpty
                        ? widget.video.description
                        : 'No description available',
                    style: GoogleFonts.poppins(
                      color: Colors.black,
                      fontSize: 14,
                    ),
                    maxLines: 10,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatViewCount(String viewCount) {
    final count = int.tryParse(viewCount) ?? 0;
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatTimeAgo(String publishedAt) {
    try {
      final date = DateTime.parse(publishedAt);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()} years ago';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()} months ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Some time ago';
    }
  }
}

// SEARCH SCREEN
class SearchScreen extends StatefulWidget {
  final String searchQuery;

  const SearchScreen({super.key, required this.searchQuery});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late Future<List<YouTubeVideo>> _searchFuture;

  @override
  void initState() {
    super.initState();
    _searchFuture = YouTubeService.searchVideos(widget.searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hasil Pencarian: "${widget.searchQuery}"'),
      ),
      body: Stack(
        children: [
          FutureBuilder<List<YouTubeVideo>>(
            future: _searchFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingIndicator();
              }

              if (snapshot.hasError) {
                return _buildErrorWidget(snapshot.error.toString());
              }

              final videos = snapshot.data ?? [];

              if (videos.isEmpty) {
                return _buildEmptyResult();
              }

              return ListView.builder(
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final video = videos[index];
                  return VideoCard(video: video);
                },
              );
            },
          ),

          // MINI PLAYER
          if (videoPlayerManager.isMiniPlayerVisible &&
              videoPlayerManager.controller != null &&
              !videoPlayerManager.isFullscreen)
            Positioned(
              bottom: 80,
              right: 16,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: 120,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        Container(
                          color: Colors.grey[800],
                          child: Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              color: Colors.white.withOpacity(0.7),
                              size: 30,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.3),
                            child: Center(
                              child: GestureDetector(
                                onTap: () {
                                  videoPlayerManager.togglePlayPause();
                                },
                                child: Icon(
                                  videoPlayerManager.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () {
                              videoPlayerManager.hideMiniPlayer();
                              videoPlayerManager.disposeController();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF1a73e8),
          ),
          const SizedBox(height: 16),
          Text(
            'Mencari "${widget.searchQuery}"...',
            style: GoogleFonts.poppins(
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'Pencarian gagal',
            style: GoogleFonts.poppins(
              color: Colors.black,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: GoogleFonts.poppins(
              color: Colors.grey,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResult() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Tidak ada hasil ditemukan',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Coba dengan kata kunci yang berbeda',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}